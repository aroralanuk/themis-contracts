// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;


/// @title Custom errors for ThemisAuction
interface IThemis {
    error AccessControl();
    error AuctionAlreadyConnected();
    error AlreadyInitialized();
    error BidAlreadyRevealed();
    error RevealAlreadyStarted();
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

    event RevealStarted();

}
