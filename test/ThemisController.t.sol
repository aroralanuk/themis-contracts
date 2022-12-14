// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

import {MockERC20} from "test/mock/MockERC20.sol";

import {IInterchainAccountRouter} from "@hyperlane-xyz/core/interfaces/IInterchainAccountRouter.sol";

import {Auction} from "src/lib/Auction.sol";

import {ThemisRouter} from "src/ThemisRouter.sol";
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
    ThemisRouter internal router = new ThemisRouter();

    ThemisAuction internal auction;
    MockThemisController internal controller;

    function setUp() public override {
        super.setUp();
        vm.roll(block.number + 1_000_000);

        auction = new ThemisAuction("Ethereal Encounters", "EE", 10_000);
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(0.1 ether)
        );


        router = new ThemisRouter();

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

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(alice, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        // TODO: fix pre-setup router
        controller.revealBid(alice, 100e6, salt, nullProof());
    }


    function commitBid(
        address from,
        uint128 bidValue,
        bytes32 salt
    )
        private
        returns (address vault)
    {
        vault = controller.getVaultAddress(
            Auction.format(originDomain, address(auction)),
            from,
            bidValue,
            salt
        );
        MockERC20(usdc).transfer(vault, bidValue);
    }

    function nullProof()
        private
        pure
        returns (ThemisController.CollateralizationProof memory proof)
    {
        return proof;
    }
}
