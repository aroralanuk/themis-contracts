// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Auction} from "src/lib/Auction.sol";
import {Bids} from "src/lib/Bids.sol";

import {ThemisAuction} from "src/ThemisAuction.sol";
import "src/IThemis.sol";

import {BaseTest} from "test/utils/BaseTest.sol";


contract ThemisAuctionTest is BaseTest {
    using Bids for Bids.Heap;
    ThemisAuction internal auction;

    function setUp() public override {
        super.setUp();

        auction = new ThemisAuction("Ethereal Encounters", "EE", 3);
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

    function testCheckBid_Revert_BeforeReveal() public {
        bytes32 salt = genBytes32();

        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(0.1 ether)
        );

        vm.expectRevert(IThemis.NotInRevealPeriod.selector);
        auction.checkBid(Auction.format(1,alice), 0.2 ether, salt);
    }

    function testCheckBid() public {
        bytes32[4] memory salts;
        for (uint256 i = 0; i < 4; i++) {
            salts[i] = genBytes32();
        }

        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(0.1 ether)
        );
        BidParams memory expected = BidParams({
            domain: 1,
            bidderAddress: alice,
            bidAmount: 0.2 ether,
            bidTimestamp: uint64(block.timestamp)
        });
        vm.warp(block.timestamp + 1 hours);

        auction.checkBid(Auction.format(1,alice), 0.2 ether, salts[0]);

        Bids.Node[] memory bids = auction.getHighestBids();
        assertBid(bids[0], expected);

    }

    function _heapContains() internal {

    }

    struct BidParams {
        uint32 domain;
        address bidderAddress;
        uint128 bidAmount;
        uint64 bidTimestamp;
    }

    function assertBid(
        Bids.Node memory bid,
        BidParams memory expected
    ) internal {
        assertEq(bid.domain, expected.domain);
        assertEq(bid.bidderAddress, expected.bidderAddress);
        assertEq(bid.bidAmount, expected.bidAmount);
        // TODO: timestamp yourt bids
        // assertEq(bid.bidTimestamp, expected.bidTimestamp);
    }

}
