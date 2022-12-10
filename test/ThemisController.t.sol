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

    function setUp() public {
        auction = new ThemisAuction("Ethereal Encounters", "EE");
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(0.1 ether)
        );

        vm.selectFork(originFork);
        vm.startBroadcast(pk);

        router = IInterchainAccountRouter(MOONBASE_ALPHA_ICA);

        controller = new MockThemisController(address(router));
    }

    function testConnectAuction() public {
        controller.connectAuction(remoteDomain, address(auction));
        assertEq(
            controller.auction(),
            Auction.format(remoteDomain, address(auction))
        );

        vm.stopBroadcast();
    }

    function testConnectAuctionRepeat_Fail() public {
        controller.connectAuction(remoteDomain, address(auction));

        vm.expectRevert();
        controller.connectAuction(originDomain, address(auction));
        assertEq(
            controller.auction(),
            Auction.format(remoteDomain, address(auction))
        );

        vm.stopBroadcast();
    }

    function testConnectAuction_FailAccessControl() public {
        switchBroadCast(alice_pk);

        vm.expectRevert();
        controller.connectAuction(originDomain, address(auction));
        assertEq(controller.auction(), Auction.format(0, address(0)));

        vm.stopBroadcast();
    }

    function testStartReveal() public {
        controller.connectAuction(remoteDomain, address(auction));

        controller.startReveal();
        console.log("revealStartBlock: %s", controller.revealStartBlock());
        // assertEq(controller.revealStartBlock(), vm.blockNumber());

        vm.stopBroadcast();
    }
}
