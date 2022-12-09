// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Auction} from "src/lib/Auction.sol";

import {ThemisAuction} from "src/ThemisAuction.sol";


contract ThemisAuctionTest is Test {
    ThemisAuction internal auction;

    function setUp() public {
        auction = new ThemisAuction("Ethereal Encounters", "EE");
    }
}
