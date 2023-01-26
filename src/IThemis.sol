// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;


/// @title Custom errors for ThemisAuction
interface IThemis {
    error AccessControl();
    error AuctionAlreadyConnected();
    error AuctionNotOver();
    error AlreadyInitialized();
    error BidAlreadyRevealed();
    error BidLowerThanReserve();
    error BidNotRevealed();
    error InsertLimitsNotSet();
    error InsertLimitsInUse();
    error InvalidTokenId();
    error RevealAlreadyStarted();
    error NoBids();
    error NotCollectionOwner();
    error NotInRevealPeriod();
    error NotReserved();
    error NotRouter();
    error NotYetRevealBlock();
    error VaultAlreadyDeployed();

    event AuctionInitialized(
        address indexed auction,
        address indexed owner,
        uint64 auctionStart,
        uint64 BidDeadline,
        uint64 RevealDeadline,
        uint128 reservePrice
    );

    event BidProvenRemote(
            uint256 timestamp,
            bytes32 indexed auction,
            address indexed bidder_,
            uint256 vaultAmount_
    );

    event BidRevealed(
        uint32 indexed discardedIndex,
        uint32 indexed bidIndex,
        uint32 domain,
        address bidderAddress,
        uint128 amount,
        uint64 timestamp
    );

    event BidFailed(
        uint256 timestamp,
        address indexed auction,
        address bidder,
        uint128 bidAmount
    );

    event BidSuccessfullyPlaced(
        uint256 timestamp,
        address indexed auction,
        address bidder,
        uint128 bidAmount
    );

    event RevealStarted(uint256 timestamp);
    event RevealStartedController(uint256 timestamp);
    event RevealEnded(uint timestamp);
    event AuctionEnded(uint256 timestamp);

    event VaultDeployed(
        bytes32 indexed auction,
        address indexed bidder,
        address indexed vault
    );

    event ReceivedToken (
        uint32 origin,
        bytes32 sender,
        string data,
        address token,
        uint256 amount
    );

    event BidShortlisted (
        uint32 indexed mintIndex,
        uint32 indexed domain,
        address indexed bidder,
        uint128 bidAmount
    );

    event Reserved (
        address indexed to,
        uint256 indexed id
    );
}
