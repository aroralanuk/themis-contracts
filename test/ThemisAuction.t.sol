// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Bids} from "src/lib/Bids.sol";

import {IThemis} from "src/IThemis.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisVault} from "src/ThemisVault.sol";


import {BaseTest} from "test/utils/BaseTest.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract ThemisAuctionWrapper is ThemisAuction {
    uint bal;

    constructor(string memory _name, string memory _symbol, uint256 _maxSupply)
        ThemisAuction(_name, _symbol, _maxSupply) {}

    function setBalance(uint _bal) public {
        bal = _bal;
    }

    // Overridden so we don't have to deal with proofs here.
    // See BalanceProofTest.sol for LibBalanceProof unit tests.
    function _getProvenAccountBalance(
        bytes[] memory /* proof */,
        bytes memory /* blockHeaderRLP */,
        bytes32 /* blockHash */,
        address /* account */
    )
        internal
        override
        view
        returns (uint256 accountBalance)
    {
        return bal;
    }
}

contract ThemisAuctionTest is BaseTest {

    using Bids for Bids.List;

    ThemisAuctionWrapper internal auction;

    uint256 constant MAX_SUPPLY = 3;

    function setUp() public override {
        super.setUp();

        auction = new ThemisAuctionWrapper("Ethereal Encounters", "EE", MAX_SUPPLY);
        auction.setCollateralToken(address(usdc));
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

    function testInitialize_Fail_NotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(IThemis.NotCollectionOwner.selector);
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );
        vm.stopPrank();
    }

    function testRevealBid() external {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        vm.startPrank(alice);
        uint128 bidVal = 100 * USDC;
        bytes32 salt = genBytes32();
        address vault = commitBid(alice, address(usdc), bidVal, salt);
        vm.warp(block.timestamp + 90 minutes);

        auction.revealBid(alice, salt, 0, 0, nullProof());

        BidParams[] memory expected = new BidParams[](1);
        expected[0] = BidParams({
            bidder: alice,
            amount: bidVal,
            blockNumber: uint64(block.number)
        });

        Bids.Element[] memory bids = auction.getHighestBids();
        assertAllBids(bids, expected);
        assertVaultRevealed(vault);
    }

    function testRevealBid_OutsideRevealWindow() external {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        vm.startPrank(alice);
        uint128 bidVal = 100 * USDC;
        bytes32 salt = genBytes32();
        address vault = commitBid(alice, address(usdc), bidVal, salt);

        // vm.expectRevert(IThemis.NotInRevealPeriod.selector);
        auction.revealBid(alice, salt, 0, 0, nullProof());

        vm.warp(block.timestamp + 3.01 hours);

        // vm.expectRevert(IThemis.NotInRevealPeriod.selector);
        auction.revealBid(alice, salt, 0, 0, nullProof());

        require(vault.code.length > 0, "Vault should be deployed");
        require(usdc.balanceOf(vault) == 0, "User should get refunded");
    }

    function testRevealBid_IncorrectSalt() external {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        vm.startPrank(alice);
        uint128 bidVal = 100 * USDC;
        bytes32 salt = genBytes32();
        address vault = commitBid(alice, address(usdc), bidVal, salt);

        vm.warp(block.timestamp + 90 minutes);

        // vm.expectRevert(IThemis.BidLowerThanReserve.selector);
        auction.revealBid(alice, genBytes32(), 0, 0, nullProof());

        require(vault.code.length == 0, "Vault shouldn't be deployed");
        require(usdc.balanceOf(vault) == 100 * USDC, "User shouldn't get refunded");
    }

    function testRevealBid_Descending() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        BidParams[] memory expected = new BidParams[](4);

        for (uint256 i = 0; i < 4; i++) {
            vm.startPrank(testUsers[i]);
            uint128 bidVal = testBids[i];
            commitBid(testUsers[i], address(usdc), bidVal, testSalts[i]);

            expected[i] = BidParams({
                bidder: testUsers[i],
                amount: testBids[i],
                blockNumber: uint64(block.number)
            });

            vm.stopPrank();
            vm.warp(block.timestamp + 60 seconds);
            vm.roll(block.number + 5);
        }
        vm.warp(block.timestamp + 90 minutes);

        for (uint256 i = 0; i < 4; i++) {
            auction.revealBid(testUsers[i], testSalts[i], testGreaterKey[i], 0, nullProof());
        }

        Bids.Element[] memory bids = auction.getHighestBids();
        assertAllBids(bids, expected);
    }

    event BidDiscarded (
        address indexed bidder,
        uint128 indexed amount,
        uint64 indexed blockNumber
    );

    function testRevealBid_Full_LowBid() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        BidParams[] memory expected = new BidParams[](4);

        for (uint256 i = 0; i < 4; i++) {
            vm.startPrank(testUsers[i]);
            commitBid(testUsers[i], address(usdc), testBids[i], testSalts[i]);

            expected[i] = BidParams({
                bidder: testUsers[i],
                amount: testBids[i],
                blockNumber: uint64(block.number)
            });

            vm.stopPrank();
            vm.warp(block.timestamp + 60 seconds);
            vm.roll(block.number + 5);
        }
        address vault = commitBid(ellie, address(usdc), 80e6, testSalts[3]);
        vm.warp(block.timestamp + 90 minutes);

        for (uint256 i = 0; i < 4; i++) {
            auction.revealBid(testUsers[i], testSalts[i], testGreaterKey[i], 0, nullProof());
        }

        // new bits - testing to see if ellie's bid gets reverted
        vm.expectEmit(true, true, false, false);
        emit BidDiscarded(ellie, 80e6, 26);
        auction.revealBid(ellie, testSalts[3], 4, 0, nullProof());

        require(vault.code.length > 0, "Vault should be deployed");
        require(usdc.balanceOf(vault) == 0, "User should get refunded");

        Bids.Element[] memory bids = auction.getHighestBids();
        assertAllBids(bids, expected);
    }

    function testRevealBid_Full_Replace() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        BidParams[] memory expected = new BidParams[](4);
        address vault;

        for (uint256 i = 0; i < 4; i++) {
            vm.startPrank(testUsers[i]);
            vault = commitBid(testUsers[i], address(usdc), testBids[i], testSalts[i]);

            expected[(i+1) % 4] = BidParams({
                bidder: testUsers[i],
                amount: testBids[i],
                blockNumber: uint64(block.number)
            });

            vm.stopPrank();
            vm.warp(block.timestamp + 60 seconds);
            vm.roll(block.number + 5);
        }
        commitBid(ellie, address(usdc), 280e6, testSalts[3]);
        expected[0] = BidParams({
            bidder: ellie,
            amount: 280e6,
            blockNumber: 26
        });

        vm.warp(block.timestamp + 90 minutes);

        for (uint256 i = 0; i < 4; i++) {
            auction.revealBid(testUsers[i], testSalts[i], testGreaterKey[i], 0, nullProof());
        }

        // new bits - testing to see if devin's bid gets pushed out
        vm.expectEmit(true, true, false, false);
        emit BidDiscarded(devin, 90e6, 21);
        auction.revealBid(ellie, testSalts[3], 0, 1, nullProof());

        require(vault.code.length == 0, "Vault shouldn be deployed");
        require(usdc.balanceOf(vault) != 0, "Devin shouldn get refunded");

        Bids.Element[] memory bids = auction.getHighestBids();
        assertAllBids(bids, expected);
    }

    function testRevealBid_Failed_PrematureWithdrawal() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        vm.startPrank(alice);
        uint128 bidVal = 100 * USDC;
        bytes32 salt = genBytes32();
        address vault = commitBid(alice, address(usdc), bidVal, salt);
        vm.warp(block.timestamp + 90 minutes);

        auction.revealBid(alice, salt, 0, 0, nullProof());

        // TODO: what if the caller has a bidAmounts function
        address coll = auction.collateralToken();
        vm.expectRevert();
        ThemisVault wannabeVault = new ThemisVault{salt: salt}(address(auction), coll, alice);
    }

    function testEndAuction_Fail_Premature() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert(IThemis.AuctionNotOver.selector);
        auction.endAuction();

        assertEq(auction.getHighestBids().length, 0);
    }

    function testEndAuction_NoBids() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        vm.warp(block.timestamp + 4 hours);
        auction.endAuction();

        assertEq(auction.getHighestBids().length, 0);
    }

    function testEndAuction_OneBid() public {
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50 * USDC)
        );

        vm.startPrank(alice);
        uint128 bidVal = 100 * USDC;
        bytes32 salt = genBytes32();
        address vault = commitBid(alice, address(usdc), bidVal, salt);
        vm.warp(block.timestamp + 90 minutes);

        auction.revealBid(alice, salt, 0, 0, nullProof());

        assertEq(auction.getHighestBids().length, 1);

        vm.warp(block.timestamp + 2 hours);
        auction.endAuction();

        assertEq(usdc.balanceOf(address(auction)), bidVal);
        assertEq(auction.ownerOf(0), alice);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    struct BidParams {
        address bidder;
        uint128 amount;
        uint64 blockNumber;
    }

    function assertBid(
        Bids.Element memory bid,
        BidParams memory expected
    ) internal {
        assertEq(bid.bidder, expected.bidder);
        assertEq(bid.amount, expected.amount);
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

    function assertVaultRevealed(address vault) internal {
        assertTrue(auction.revealedVaults(vault));
    }

    function nullProof()
        private
        pure
        returns (ThemisAuction.CollateralizationProof memory proof)
    {
        return proof;
    }

    function commitBid(
        address from,
        address collateral,
        uint128 amount,
        bytes32 salt
    )
        private
        returns (address vault)
    {
        vault = auction.getVaultAddress(address(auction), collateral, from, salt);

        MockERC20(collateral).transfer(vault, amount);
    }
}
