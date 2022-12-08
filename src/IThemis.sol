// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;


/// @title Custom errors for ThemisAuction
interface IThemis {
    error AlreadyInitialized();

    event AuctionInitialized(
        address indexed auction,
        address indexed owner,
        uint64 bidPeriod,
        uint64 revealPeriod,
        uint128 reservePrice
    );
}
