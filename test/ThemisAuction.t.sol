// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Auction} from "src/lib/Auction.sol";

import {ThemisAuction} from "src/ThemisAuction.sol";

import {BaseTest} from "test/utils/BaseTest.sol";


contract ThemisAuctionTest is BaseTest {
    ThemisAuction internal auction;

    function setUp() public override {
        super.setUp();

        auction = new ThemisAuction("Ethereal Encounters", "EE", 10_000);
    }

    function testInitialize() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(0.1 ether)
        );

        assertEq(auction.endOfBiddingPeriod(), block.timestamp + 1 hours);
        assertEq(auction.endOfRevealPeriod(), block.timestamp + 3 hours);
        assertEq(auction.reservePrice(), 0.1 ether);
    }

    function testCheckBid() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(0.1 ether)
        );

        auction.checkBid(alice, 0.2 ether);
        auction.checkBid(bob, 0.5 ether);
        auction.checkBid(charlie, 0.3 ether);

        // assertEq(auction.)
    }

    function _heapContains() internal {

    }
}
