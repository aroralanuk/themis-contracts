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
    error InvalidTokenId();
    error RevealAlreadyStarted();
    error NotInRevealPeriod();
    error NotReserved();
    error NotYetRevealBlock();

    event AuctionInitialized(
        address indexed auction,
        address indexed owner,
        uint64 bidPeriod,
        uint64 revealPeriod,
        uint128 reservePrice
    );

    event BidProvenRemote(
            uint256 timestamp,
            bytes32 indexed auction,
            address indexed bidder_,
            uint256 vaultAmount_
    );

    event BidRevealed(
        address indexed auction,
        bytes32 indexed bidder,
        uint128 bidAmount
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

    event RevealStarted();
    event AuctionEnded();

    event VaultDeployed(
        bytes32 indexed auction,
        address indexed bidder,
        address indexed vault
    );

}
