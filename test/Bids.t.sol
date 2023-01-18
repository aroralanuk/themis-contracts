// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.15;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";

// import "src/lib/Bids.sol";

// import "test/utils/BaseTest.sol";

// contract BidsTest is BaseTest {
//     using Bids for Bids.Heap;

//     Bids.Heap internal bids;
//     uint32 constant MAX_SUPPLY = 2;

//     function setUp() public override {
//         bids.init(MAX_SUPPLY + 1);

//         assertEq(bids.totalBids, 0);
//         assertEq(bids.capacity, MAX_SUPPLY + 1);
//     }

//     function testInsert_FirstElement() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         assertEq(bids.totalBids, 1);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function testInsert_123() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 3,
//                 bidderAddress: charlie,
//                 bidAmount: 250e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 2,
//                 nextKey: 0
//             })
//         );

//         assertEq(bids.totalBids, 3);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function testInsert_12_fail() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         vm.expectRevert(Bids.InvalidLesserKey.selector);
//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 50e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         assertEq(bids.totalBids, 1);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function testInsert_132_fail() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         vm.expectRevert(Bids.InvalidLesserKey.selector);
//         bids.insert(
//             Bids.Node({
//                 domain: 3,
//                 bidderAddress: charlie,
//                 bidAmount: 150e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 2,
//                 nextKey: 0
//             })
//         );

//         assertEq(bids.totalBids, 2);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function testInsert_123_fail() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         vm.expectRevert(Bids.InvalidGreaterKey.selector);
//         bids.insert(
//             Bids.Node({
//                 domain: 3,
//                 bidderAddress: charlie,
//                 bidAmount: 250e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 2
//             })
//         );

//         assertEq(bids.totalBids, 2);
//         assertBidsOrder(bids.getAllBids());
//     }


//     function testInsert_132() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 3,
//                 bidderAddress: charlie,
//                 bidAmount: 150e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 2
//             })
//         );

//         assertEq(bids.totalBids, 3);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function testInsert_312() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 3,
//                 bidderAddress: charlie,
//                 bidAmount: 50e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 1
//             })
//         );

//         assertEq(bids.totalBids, 3);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function testInsert_132_timestamp() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         vm.warp(block.timestamp + 5);

//         bids.insert(
//             Bids.Node({
//                 domain: 3,
//                 bidderAddress: charlie,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 2
//             })
//         );

//         assertEq(bids.totalBids, 3);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function testInsert_132_overflow() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 3,
//                 bidderAddress: charlie,
//                 bidAmount: 150e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 2
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 4,
//                 bidderAddress: devin,
//                 bidAmount: 90e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 1
//             })
//         );

//         assertEq(bids.totalBids, 3);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function testInsert_432_overflow() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 3,
//                 bidderAddress: charlie,
//                 bidAmount: 150e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 2
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 4,
//                 bidderAddress: devin,
//                 bidAmount: 110e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 3
//             })
//         );

//         assertEq(bids.totalBids, 3);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function testInsert_324_overflow() public {
//         bids.insert(
//             Bids.Node({
//                 domain: 1,
//                 bidderAddress: alice,
//                 bidAmount: 100e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 0,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 2,
//                 bidderAddress: bob,
//                 bidAmount: 200e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 0
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 3,
//                 bidderAddress: charlie,
//                 bidAmount: 150e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 1,
//                 nextKey: 2
//             })
//         );

//         bids.insert(
//             Bids.Node({
//                 domain: 4,
//                 bidderAddress: devin,
//                 bidAmount: 250e6,
//                 bidTimestamp: uint64(block.timestamp),
//                 prevKey: 2,
//                 nextKey: 0
//             })
//         );

//         assertEq(bids.totalBids, 3);
//         assertBidsOrder(bids.getAllBids());
//     }

//     function assertBidsOrder(Bids.Node[] memory bidsArray)
//         internal pure returns (bool)
//     {
//         for (uint i = 0; i < bidsArray.length - 1; i++) {
//             Bids.Node memory element = bidsArray[i];
//             Bids.Node memory nextElement = bidsArray[i + 1];
//             if (!Bids.lt(element, nextElement)) {
//                 return false;
//             }
//         }
//         return true;
//     }
// }
