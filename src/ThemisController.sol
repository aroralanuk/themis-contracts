// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// import "forge-std/console.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {XAddress} from "src/lib/XAddress.sol";
import {LibBalanceProof} from "src/lib/LibBalanceProof.sol";

import {IThemis} from "src/IThemis.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisVault} from "src/ThemisVault.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";

contract ThemisController is IThemis {
    using XAddress for XAddress.Info;

    XAddress.Info internal _auction;
    XAddress.Info internal _router;
    XAddress.Info internal _bidder;

    mapping(address => bool) revealedVault;

    address owner;
    address public collateralToken;

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

    ThemisRouter routerContract;

    modifier onlyOwner() {
        if (msg.sender != owner) revert AccessControl();
        _;
    }

    constructor(address router_) {
        routerContract = ThemisRouter(router_);
        _router.init(routerContract.getDomain(), router_);
        owner = msg.sender;
    }

    function auction() public view returns (bytes32) {
        return _auction.toBytes32();
    }

    function connectAuction(uint32 domain_, address contract_)
        onlyOwner external
    {
        if (_auction.toBytes32() != bytes32(0))
            revert AuctionAlreadyConnected();
        _auction.init(domain_, contract_);
    }

    function setCollateralToken(address token_) public onlyOwner {
        collateralToken = token_;
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
        emit RevealStartedController(block.timestamp);
    }

    function revealBid(
        address bidder_,
        bytes32 salt_,
        CollateralizationProof calldata proof_
    ) external returns (address vault){
        vault = getVaultAddress(bidder_, salt_);

        // JUST FOR TESTING
        uint128 vaultBalance = uint128(ERC20(collateralToken).balanceOf(vault));

        // uint128 vaultBalance = uint128(
        //     _getProvenAccountBalance(
        //         proof_.accountMerkleProof,
        //         proof_.blockHeaderRLP,
        //         storedBlockHash,
        //         vault
        //     )
        // );

        _bidder.init(_router.getDomain(), bidder_);

        routerContract.dispatchWithCallback(
            _auction.getDomain(),
            _auction.getAddress(),
            abi.encodeCall(
                ThemisAuction(_auction.getAddress()).checkBid,
                (
                    _bidder.toBytes32(),
                    vaultBalance,
                    salt_
                )
            ),
            abi.encodePacked(this.revealBidCallback.selector)
        );

        emit BidProvenRemote(
            block.timestamp,
            _auction.toBytes32(),
            bidder_,
            vaultBalance
        );
    }

    function revealBidCallback(
        address bidder_,
        uint128 bidAmount_,
        bytes32 salt_,
        bool success_
    ) public {
        address vault = getVaultAddress(bidder_, salt_);

        // testing for now
        // if (revealedVault[vault]) revert BidAlreadyRevealed();
        success_ = true;

        revealedVault[vault] = true;

        if (!success_) {
            new ThemisVault{salt: salt_}(
                _auction.toBytes32(),
                collateralToken,
                bidder_
            );

            emit BidFailed(
                block.timestamp,
                _auction.getAddress(),
                bidder_,
                bidAmount_
            );
        } else {
            emit BidSuccessfullyPlaced(
                block.timestamp,
                _auction.getAddress(),
                bidder_,
                bidAmount_
            );
        }
    }

    function deployVaultOnReveal(
        address bidder_,
        uint128 bidAmount_,
        bytes32 salt_
    ) external returns (uint32 transferReceipt) {
        // TODO: restrict to router

        bidAmounts[bidder_] = bidAmount_;
        address vault = getVaultAddress(bidder_, salt_);

        if (!revealedVault[vault]) revert BidNotRevealed();
        if (vault.code.length != 0) revert VaultAlreadyDeployed();

        ThemisVault _vault = new ThemisVault{salt: salt_}(
            _auction.toBytes32(),
            collateralToken,
            bidder_
        );

        ERC20(collateralToken).approve(_router.getAddress(), bidAmount_);
        routerContract.dispatchWithTokens(
            _auction.getDomain(),
            _auction.toBytes32(),
            hex"deadbeef",
            collateralToken,
            bidAmount_,
            "Circle"
        );

        transferReceipt = _vault.getLiquidityReceipt();
        // transfer receipt

        emit VaultDeployed(
            _auction.toBytes32(),
            bidder_,
            vault
        );
    }

    function getVaultAddress(address bidder_, bytes32 salt_)
        public view returns (address vault)
    {
        return _getVaultAddress(
            _auction.toBytes32(),
            collateralToken,
            bidder_,
            salt_
        );
    }



    /// @notice computes the `CREATE2` address of the `ThemisVault` with the
    /// given paramters. The vault may not be deployed yet.
    /// @param auction_ The auction for which the vault is being created
    /// @param collateralToken_ The collateral token used for the vault
    /// @param bidder_ The bidder who deposited the collateral to this vault
    /// @param salt_ The salt used to create the vault
    /// @return vault The address of the vault
    function _getVaultAddress(
        bytes32 auction_,
        address collateralToken_,
        address bidder_,
        bytes32 salt_
    ) internal view returns (address vault) {
        // Compute `CREATE2` address of vault
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt_,
            keccak256(abi.encodePacked(
                type(ThemisVault).creationCode,
                abi.encode(
                    auction_,
                    collateralToken_,
                    bidder_
                )
            ))
        )))));
    }

    /// @dev Gets the balance of the given account at a past block by
    ///      traversing the given Merkle proof for the state trie. Wraps
    ///      LibBalanceProof.getProvenAccountBalance so that this function
    ///      can be overriden for testing.
    /// @param proof_ A Merkle proof for the given account's balance in
    ///        the state trie of a past block.
    /// @param blockHeaderRLP_ The RLP-encoded block header for the past
    ///        block for which the balance is being queried.
    /// @param blockHash_ The expected blockhash. Should be equal to the
    ///        Keccak256 hash of `blockHeaderRLP`.
    /// @param account_ The account whose past balance is being queried.
    /// @return accountBalance The proven past balance of the account.
    function _getProvenAccountBalance(
        bytes[] memory proof_,
        bytes memory blockHeaderRLP_,
        bytes32 blockHash_,
        address account_
    )
        internal
        virtual
        view
        returns (uint256 accountBalance)
    {
        return LibBalanceProof.getProvenAccountBalance(
            proof_,
            blockHeaderRLP_,
            blockHash_,
            account_
        );
    }

    function max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }
}
