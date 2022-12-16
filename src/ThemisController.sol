// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";


import {Auction} from "src/lib/Auction.sol";
import {LibBalanceProof} from "src/lib/LibBalanceProof.sol";

import {IThemis} from "src/IThemis.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisVault} from "src/ThemisVault.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";
import {Call} from "@hyperlane-xyz/core/contracts/Call.sol";



contract ThemisController is IThemis {
    bytes32 public auction;
    mapping(address => bool) revealedVault;

    address owner;
    address collateralToken;

    uint96 public revealStartBlock;
    bytes32 public storedBlockHash;

    bool isCollateralized;
    mapping (address => uint128) public bidReqd;

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
                (bidder, vaultBalance, salt)
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

    function getBidRequired(address _bidder) external view returns (uint128) {
        return bidReqd[_bidder];
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
