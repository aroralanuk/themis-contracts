// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

import {IInterchainAccountRouter} from "@hyperlane-xyz/core/interfaces/IInterchainAccountRouter.sol";

import {Auction} from "src/lib/Auction.sol";

import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisController} from "src/ThemisController.sol";

import {BaseTest} from "./utils/BaseTest.sol";

contract MockThemisController is ThemisController {
    uint256 bal;

    constructor(address accountRouterAddress_)
        ThemisController(accountRouterAddress_) {}

    function setBalance(uint256 _bal) external {
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


contract ThemisControllerTest is BaseTest {
    IInterchainAccountRouter internal router;

    ThemisAuction internal auction;
    MockThemisController internal controller;

    function setUp() public override {
        super.setUp();

        vm.selectFork(originFork);
        // vm.startBroadcast(pk);

        auction = new ThemisAuction("Ethereal Encounters", "EE", 10_000);
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(0.1 ether)
        );

        vm.makePersistent(address(auction));
        assert(vm.isPersistent(address(auction)));
        vm.selectFork(remoteFork);
        assert(vm.isPersistent(address(auction)));

        router = IInterchainAccountRouter(MOONBASE_ALPHA_ICA);

        controller = new MockThemisController(address(router));
    }

    function testConnectAuction() public {
        controller.connectAuction(originDomain, address(auction));
        assertEq(
            controller.auction(),
            Auction.format(originDomain, address(auction))
        );
    }

    function testConnectAuctionRepeat_Fail() public {
        controller.connectAuction(originDomain, address(auction));

        vm.expectRevert();
        controller.connectAuction(remoteDomain, address(auction));
        assertEq(
            controller.auction(),
            Auction.format(originDomain, address(auction))
        );
    }

    function testConnectAuction_FailAccessControl() public {

        vm.startPrank(alice);
        vm.expectRevert();
        controller.connectAuction(originDomain, address(auction));
        assertEq(controller.auction(), Auction.format(0, address(0)));

        vm.stopPrank();
    }

    function testStartReveal() public {
        controller.connectAuction(originDomain, address(auction));
        controller.startReveal();

        assertEq(controller.revealStartBlock(), block.number);
        assertEq(controller.storedBlockHash(), blockhash(block.number - 256));
    }

    function testStartRevealRepeat_Fail() public {
        controller.connectAuction(originDomain, address(auction));
        controller.startReveal();

        vm.expectRevert();
        controller.startReveal();
    }

    function testRevealBid() public {
        controller.connectAuction(originDomain, address(auction));
        controller.startReveal();

        // TODO: fix this
        // controller.revealBid(address(this), 1 ether, genBytes32(), nullProof());

        // cons
        // assertEq(controller.bids(1 ether), 1);
    }

    function nullProof()
        private
        pure
        returns (ThemisController.CollateralizationProof memory proof)
    {
        return proof;
    }
}
