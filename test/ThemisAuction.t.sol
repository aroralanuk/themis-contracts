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

    uint256 constant MAX_SUPPLY = 3;

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
                domain: testDomains[i],
                bidderAddress: testUsers[i],
                bidAmount: testBids[i],
                bidTimestamp: uint64(block.timestamp + i)
            });
            auction.checkBid(
                Auction.format(testDomains[i],
                testUsers[i]),
                testBids[i],
                salt
            );
        }

        Bids.Node[] memory bids = auction.getHighestBids();
        assertAllBids(bids, expected);
    }

    function testCheckBid_Descending() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        vm.warp(block.timestamp + 1 hours);
        for (uint256 j = MAX_SUPPLY; j > 0; j--) {
            uint i = j - 1;
            salt = genBytes32();

            auction.checkBid(
                Auction.format(testDomains[i],
                testUsers[i]),
                testBids[i],
                salt
            );
        }

        Bids.Node[] memory bids = auction.getHighestBids();
        assertHeapProperty(bids);
    }

    function testCheckBid_Random() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        vm.warp(block.timestamp + 1 hours);

        for (uint256 i = 0; i < 3; i++) {
            salt = genBytes32();
            // [alice, bob, charlie]
            uint r = i * 386_231 % 3;
            auction.checkBid(
                Auction.format(testDomains[r],
                testUsers[r]),
                testBids[r],
                salt
            );
        }

        Bids.Node[] memory bids = auction.getHighestBids();
        assertHeapProperty(bids);
    }

    function testCheckBid_Full_LowBid() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        vm.warp(block.timestamp + 1 hours);
        BidParams[] memory expected = new BidParams[](MAX_SUPPLY);
        for (uint256 i = 0; i < 4; i++) {
            salt = genBytes32();
            // [alice, bob, charlie]
            if (i < 3) {
                expected[i] = BidParams({
                    domain: testDomains[i],
                    bidderAddress: testUsers[i],
                    bidAmount: testBids[i],
                    bidTimestamp: uint64(block.timestamp + i)
                });
            }
            auction.checkBid(
                Auction.format(testDomains[i],
                testUsers[i]),
                testBids[i],
                salt
            );
        }

        Bids.Node[] memory bids = auction.getHighestBids();
        assertAllBids(bids, expected);
    }

    function testCheckBid_Full_HighestBid() public {
        testBids[3] = 250e6;
        expectedUsers = [bob, devin, charlie];
        expectedDomains = [1, 69, 3];
        expectedBids = [150e6, 250e6, 200e6];

        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        vm.warp(block.timestamp + 1 hours);
        BidParams[] memory expected = new BidParams[](MAX_SUPPLY);

        for (uint256 i = 0; i < 4; i++) {
            salt = genBytes32();
            // [bob, devin, charlie]
            if (i < 3) {
                expected[i] = BidParams({
                    domain: expectedDomains[i],
                    bidderAddress: expectedUsers[i],
                    bidAmount: expectedBids[i],
                    bidTimestamp: uint64(block.timestamp + i)
                });
            }
            auction.checkBid(
                Auction.format(testDomains[i],
                testUsers[i]),
                testBids[i],
                salt
            );
        }

        Bids.Node[] memory bids = auction.getHighestBids();
        assertAllBids(bids, expected);
        assertHeapProperty(bids);
    }

    function testCheckBid_Full_JustEnoughBid() public {
        testBids[3] = 110e6;
        expectedUsers = [devin, bob, charlie];
        expectedDomains = [69, 1, 3];
        expectedBids = [110e6, 150e6, 200e6];

        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        vm.warp(block.timestamp + 1 hours);
        BidParams[] memory expected = new BidParams[](MAX_SUPPLY);

        for (uint256 i = 0; i < 4; i++) {
            salt = genBytes32();
            // [bob, devin, charlie]
            if (i < 3) {
                expected[i] = BidParams({
                    domain: expectedDomains[i],
                    bidderAddress: expectedUsers[i],
                    bidAmount: expectedBids[i],
                    bidTimestamp: uint64(block.timestamp + i)
                });
            }
            auction.checkBid(
                Auction.format(testDomains[i],
                testUsers[i]),
                testBids[i],
                salt
            );
        }

        Bids.Node[] memory bids = auction.getHighestBids();
        assertAllBids(bids, expected);
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

    function assertAllBids(
        Bids.Node[] memory bids,
        BidParams[] memory expected
    ) internal {
        assertEq(bids.length, expected.length);
        for (uint256 i = 0; i < bids.length; i++) {
            assertBid(bids[i], expected[i]);
        }
    }

    function assertHeapProperty(Bids.Node[] memory bids) internal pure {
        require(bids.length == MAX_SUPPLY);
        for (uint256 i = 0; i < bids.length; i++) {
            uint256 left = 2 * i + 1;
            uint256 right = 2 * i + 2;
            if (left < bids.length) {
                require(
                    bids[i].bidAmount <= bids[left].bidAmount, "HEAP_PROPERTY_VIOLATED"
                );
            }
            if (right < bids.length) {
                require(
                    bids[i].bidAmount <= bids[right].bidAmount, "HEAP_PROPERTY_VIOLATED"
                );
            }
        }
    }

}
