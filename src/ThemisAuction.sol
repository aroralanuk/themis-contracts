// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ERC721} from "solmate/tokens/ERC721.sol";

import {IThemis} from "./IThemis.sol";

contract ThemisAuction is IThemis, ERC721 {
    string public BASE_ASSET_URI;

    address public collectionOwner;

    uint64 public endOfBiddingPeriod;
    uint64 public endOfRevealPeriod;
    uint128 reservePrice;

    mapping(uint256 => uint64) highestBid;
    mapping(uint256 => address) highestBidVault;
    mapping(uint256 => uint64) secondHighestBid;

    constructor (
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {
        collectionOwner = msg.sender;
    }

    function initialize(
        uint64 bidPeriod_,
        uint64 revealPeriod_,
        uint128 reservePrice_
    ) external {
        if (endOfBiddingPeriod == 0) revert AlreadyInitialized();

        endOfBiddingPeriod = uint64(block.timestamp) + bidPeriod_;
        endOfRevealPeriod =
            uint64(block.timestamp) + bidPeriod_ + revealPeriod_;
        reservePrice = reservePrice_;

        emit AuctionInitialized(
            address(this),
            msg.sender,
            bidPeriod_,
            revealPeriod_,
            reservePrice
        );
    }

    function placeBid(address bidder_, uint64 bidAmount_) external {}

    function lateRevealBid() external {}

    function endAuction() external {}


    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(BASE_ASSET_URI, id));
    }
}
