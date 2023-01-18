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

contract ThemisAuctionTest is BaseTest {
    using Bids for Bids.Heap;
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
            auction.checkBid(
                _bidder.toBytes32(),
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

            _bidder.init(testDomains[i], testUsers[i]);
            auction.checkBid(
                _bidder.toBytes32(),
                testBids[i],
                salt
            );
        }
        assertHeapProperty(auction.getHighestBids());
    }

    function testCheckBid_Full_LowBid() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );

        vm.warp(block.timestamp + 1 hours);

        for (uint256 i = 0; i < 4; i++) {
            salt = genBytes32();
            // [alice, bob, charlie]

            _bidder.init(testDomains[i], testUsers[i]);
            auction.checkBid(
                _bidder.toBytes32(),
                testBids[i],
                salt
            );
        }
        assertHeapProperty(auction.getHighestBids());
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

    function testAddress() public {
        address alice = 0x9B342ea9775950b39b522a35C91970b46f5A9184;
        uint32 domain = 5;

        _bidder.init(domain, alice);
        console.log(_bidder.getAddress());
        console.log(_bidder.getDomain());

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
        require(bids.length == 3);
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
