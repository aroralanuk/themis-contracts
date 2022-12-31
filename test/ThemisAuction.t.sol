// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {XAddress} from "src/lib/XAddress.sol";
import {Bids} from "src/lib/Bids.sol";

import {IThemis} from "src/IThemis.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";


import {BaseTest} from "test/utils/BaseTest.sol";
import {BidsTest} from "test/Bids.t.sol";


contract ThemisAuctionTest is BaseTest {
    using Bids for Bids.List;
    using XAddress for XAddress.Info;

    XAddress.Info internal _bidder;
    ThemisAuction internal auction;
    ThemisRouter internal router;

    uint256 constant MAX_SUPPLY = 3;

    function setUp() public override {
        super.setUp();
        auction = new ThemisAuction("Ethereal Encounters", "EE", MAX_SUPPLY);

        router = new ThemisRouter();
        auction.setRouter(address(router));
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

        _bidder.init(1, alice);

        auction.setInsertLimits(0, 0);

        vm.expectRevert(IThemis.NotInRevealPeriod.selector);
        auction.checkBid(_bidder.toBytes32(), 0.2 ether, salt);
    }

    function testCheckBid_Ascending() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        vm.warp(block.timestamp + 1 hours);
        BidParams[] memory expected = new BidParams[](3);
        for (uint256 i = 0; i < 3; i++) {
            salt = genBytes32();
            // [alice, bob, charlie]
            expected[i] = BidParams({
                domain: testDomains[2-i],
                bidderAddress: testUsers[2-i],
                bidAmount: testBids[2-i],
                bidTimestamp: uint64(block.timestamp + i)
            });
            _bidder.init(testDomains[i], testUsers[i]);
            auction.setInsertLimits(testLesserKey[i], testGreaterKey[i]);
            auction.checkBid(
                _bidder.toBytes32(),
                testBids[i],
                salt
            );
        }

        Bids.Element[] memory bids = auction.getHighestBids();
        assertAllBids(bids, expected);
    }

    function testCheckBid_Descending() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        testLesserKey = [0, 0, 0];
        testGreaterKey = [2, 1, 0];

        vm.warp(block.timestamp + 1 hours);
        for (uint256 j = MAX_SUPPLY; j > 0; j--) {
            uint i = j - 1;
            salt = genBytes32();

            _bidder.init(testDomains[i], testUsers[i]);
            auction.setInsertLimits(testLesserKey[i], testGreaterKey[i]);
            auction.checkBid(
                _bidder.toBytes32(),
                testBids[i],
                salt
            );
        }
        assertBidsOrder(auction.getHighestBids());
    }

    function testCheckBid_Full_LowBid() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        testLesserKey = [0,1,2,0];
        testGreaterKey = [0,0,0,1];

        vm.warp(block.timestamp + 1 hours);

        for (uint256 i = 0; i < 4; i++) {
            salt = genBytes32();
            // [alice, bob, charlie]

            _bidder.init(testDomains[i], testUsers[i]);

            auction.setInsertLimits(testLesserKey[i], testGreaterKey[i]);
            auction.checkBid(
                _bidder.toBytes32(),
                testBids[i],
                salt
            );
        }
        assertBidsOrder(auction.getHighestBids());
    }

    function testEndAuction_NoBids() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        vm.warp(block.timestamp + 3 hours);
        auction.endAuction();

        assertEq(auction.getHighestBids().length, 0);
    }

    function testEndAuction_OneBid() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        vm.warp(block.timestamp + 1 hours);
        salt = genBytes32();
        _bidder.init(testDomains[0], testUsers[0]);
        auction.setInsertLimits(testLesserKey[0], testGreaterKey[0]);
        auction.checkBid(
            _bidder.toBytes32(),
            testBids[0],
            salt
        );

        vm.warp(block.timestamp + 2 hours);
        // TODO: router setup
        // auction.endAuction();

        assertEq(auction.getHighestBids().length, 1);
    }

    struct BidParams {
        uint32 domain;
        address bidderAddress;
        uint128 bidAmount;
        uint64 bidTimestamp;
    }

    function assertBid(
        Bids.Element memory bid,
        BidParams memory expected
    ) internal {
        assertEq(bid.domain, expected.domain);
        assertEq(bid.bidderAddress, expected.bidderAddress);
        assertEq(bid.bidAmount, expected.bidAmount);
    }

    function assertAllBids(
        Bids.Element[] memory bids,
        BidParams[] memory expected
    ) internal {
        assertEq(bids.length, expected.length);
        for (uint256 i = 0; i < bids.length; i++) {
            assertBid(bids[i], expected[i]);
        }
    }

    function assertBidsOrder(Bids.Element[] memory bidsArray)
        internal pure returns (bool)
    {
        for (uint i = 0; i < bidsArray.length - 1; i++) {
            Bids.Element memory element = bidsArray[i];
            Bids.Element memory nextElement = bidsArray[i + 1];
            if (!Bids.lt(element, nextElement)) {
                return false;
            }
        }
        return true;
    }
}
