// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Auction} from "src/lib/Auction.sol";
import {LibBalanceProof} from "src/lib/LibBalanceProof.sol";

import {IThemis} from "src/IThemis.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisVault} from "src/ThemisVault.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";


contract ThemisController is IThemis {
    bytes32 public auction;
    mapping(address => bool) revealedVault;

    address owner;
    address collateralToken;

    uint96 public revealStartBlock;
    bytes32 public storedBlockHash;

    bool isCollateralized;
    mapping (address => uint128) public bidAmounts;

    /// @dev A Merkle proof and block header, in conjunction with the
    ///      stored `collateralizationDeadlineBlockHash` for an auction,
    ///      is used to prove that a bidder's `SneakyVault` was sufficiently
    ///      collateralized by the time the first bid was revealed.
    /// @param accountMerkleProof The Merkle proof of a particular account's
    ///        state, as returned by the `eth_getProof` RPC method.
    /// @param blockHeaderRLP The RLP-encoded header of the block
    ///        for which the account balance is being proven.
    struct CollateralizationProof {
        bytes[] accountMerkleProof;
        bytes blockHeaderRLP;
    }

    ThemisRouter router;

    modifier onlyOwner() {
        if (msg.sender != owner) revert AccessControl();
        _;
    }

    constructor(address routerAddress_) {
        router = ThemisRouter(routerAddress_);
        owner = msg.sender;
    }

    function connectAuction(uint32 domain_, address contract_)
        onlyOwner external
    {
        if (auction != bytes32(0)) revert AuctionAlreadyConnected();
        auction = Auction.format(domain_, contract_);
    }

    function setCollateralToken(address _token) public onlyOwner {
        collateralToken = _token;
    }

    function startReveal() external onlyOwner {
        if (storedBlockHash != bytes32(0)) revert RevealAlreadyStarted();
        uint256 revealStartBlockCached = revealStartBlock;
        if (block.number <= revealStartBlockCached) revert NotYetRevealBlock();
        storedBlockHash = blockhash(
            max(block.number - 256, revealStartBlockCached)
        );
        // overwrite reveal start block
        revealStartBlock = uint96(block.number);
        emit RevealStarted();
    }

    function revealBid(
        address bidder,
        bytes32 salt,
        CollateralizationProof calldata proof
    ) external returns (address vault){
        vault = getVaultAddress(
            auction,
            collateralToken,
            bidder,
            salt
        );

        if (revealedVault[vault]) revert BidAlreadyRevealed();
        revealedVault[vault] = true;

        uint128 vaultBalance = uint128(
            _getProvenAccountBalance(
                proof.accountMerkleProof,
                proof.blockHeaderRLP,
                storedBlockHash,
                vault
            )
        );

        address auctionContract = Auction.getAuctionAddress(auction);

        router.dispatchWithCallback(
            Auction.getDomain(auction),
            auctionContract,
            abi.encodeCall(
                ThemisAuction(auctionContract).checkBid,
                (Auction.format(1, bidder), vaultBalance, salt)
            ),
            abi.encodePacked(this.revealBidCallback.selector)
        );

        emit BidProvenRemote(
            block.timestamp,
            auction,
            bidder,
            vaultBalance
        );
    }

    function revealBidCallback(
        address _bidder,
        uint128 _bidAmount,
        bytes32 _salt,
        bool success
    ) public {
        address auctionContract = Auction.getAuctionAddress(auction);

        if (!success) {
            new ThemisVault{salt: _salt}(
                auction,
                collateralToken,
                _bidder
            );

            emit BidFailed(
                block.timestamp,
                auctionContract,
                _bidder,
                _bidAmount
            );
        } else {
            emit BidSuccessfullyPlaced(
                block.timestamp,
                auctionContract,
                _bidder,
                _bidAmount
            );
        }
    }

    function deployVaultOnReveal(
        address bidder,
        uint128 _bidAmount,
        bytes32 salt
    ) external returns (uint32 transferReceipt) {
        // restrict to router
        bidAmounts[bidder] = _bidAmount;
        address vault = getVaultAddress(
            auction,
            collateralToken,
            bidder,
            salt
        );


        ThemisVault _vault = new ThemisVault{salt: salt}(
            auction,
            collateralToken,
            bidder
        );
        console.log("Balance : ", ERC20(collateralToken).balanceOf(address(this)));

        ERC20(collateralToken).approve(address(router), _bidAmount);
        router.dispatchWithTokens(
            Auction.getDomain(auction),
            auction,
            hex"deadbeef",
            collateralToken,
            _bidAmount,
            "Circle"
        );

        transferReceipt = _vault.getLiquidityReceipt();
        // transfer receipt

        emit VaultDeployed(
            auction,
            bidder,
            vault
        );
    }


    /// @notice computes the `CREATE2` address of the `ThemisVault` with the
    /// given paramters. The vault may not be deployed yet.
    /// @param _auction The auction for which the vault is being created
    /// @param _collateralToken The collateral token used for the vault
    /// @param bidder The bidder who deposited the collateral to this vault
    /// @param salt The salt used to create the vault
    /// @return vault The address of the vault
    function getVaultAddress(
        bytes32 _auction,
        address _collateralToken,
        address bidder,
        bytes32 salt
    ) public view returns (address vault) {
        // Compute `CREATE2` address of vault
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(abi.encodePacked(
                type(ThemisVault).creationCode,
                abi.encode(
                    _auction,
                    _collateralToken,
                    bidder
                )
            ))
        )))));
    }

    /// @dev Gets the balance of the given account at a past block by
    ///      traversing the given Merkle proof for the state trie. Wraps
    ///      LibBalanceProof.getProvenAccountBalance so that this function
    ///      can be overriden for testing.
    /// @param proof A Merkle proof for the given account's balance in
    ///        the state trie of a past block.
    /// @param blockHeaderRLP The RLP-encoded block header for the past
    ///        block for which the balance is being queried.
    /// @param blockHash The expected blockhash. Should be equal to the
    ///        Keccak256 hash of `blockHeaderRLP`.
    /// @param account The account whose past balance is being queried.
    /// @return accountBalance The proven past balance of the account.
    function _getProvenAccountBalance(
        bytes[] memory proof,
        bytes memory blockHeaderRLP,
        bytes32 blockHash,
        address account
    )
        internal
        virtual
        view
        returns (uint256 accountBalance)
    {
        return LibBalanceProof.getProvenAccountBalance(
            proof,
            blockHeaderRLP,
            blockHash,
            account
        );
    }

    function max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }
}
