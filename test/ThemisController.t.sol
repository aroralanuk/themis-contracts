// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

import {MockERC20} from "test/mock/MockERC20.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {CircleBridgeAdapter} from "@hyperlane-xyz/core/contracts/middleware/liquidity-layer/adapters/CircleBridgeAdapter.sol";


import {Auction} from "src/lib/Auction.sol";

import {ThemisRouter} from "src/ThemisRouter.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisController} from "src/ThemisController.sol";

import {BaseTest} from "./utils/BaseTest.sol";

import {MockHyperlaneEnvironment} from "test/mock/MockHyperlaneEnvironment.sol";
import {MockCircleBridge} from "test/mock/MockCircleBridge.sol";
import {MockCircleMessageTransmitter} from "test/mock/MockCircleMessageTransmitter.sol";

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
    ThemisRouter internal router;
    ThemisRouter internal remoteRouter;

    ThemisAuction internal auction;
    MockThemisController internal controller;

    // liquidity layer mock
    MockHyperlaneEnvironment testEnv;
    string bridge = "Circle";
    CircleBridgeAdapter bridgeAdapter;
    MockCircleBridge circleBridge;
    MockCircleMessageTransmitter messageTransmitter;

    function setUp() public override {
        super.setUp();
        vm.roll(block.number + 1_000_000);

        originDomain = 1; // domain for auction
        remoteDomain = 2; // domain for controller

        testEnv = new MockHyperlaneEnvironment(remoteDomain, originDomain);
        auction = new ThemisAuction("Ethereal Encounters", "EE", 10_000);
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(0.1 ether)
        );


        router = new ThemisRouter();
        router.initialize(
            address(testEnv.mailboxes(remoteDomain)),
            originDomain
        );
        router.enrollRemoteRouter(
            originDomain,
            TypeCasts.addressToBytes32(alice)
        );


        circleBridge = new MockCircleBridge(usdc);
        messageTransmitter = new MockCircleMessageTransmitter(usdc);
        bridgeAdapter = new CircleBridgeAdapter();
        bridgeAdapter.initialize(
            address(this),
            address(circleBridge),
            address(messageTransmitter),
            address(remoteRouter)
        );
        router.setLiquidityLayerAdapter(
            bridge,
            address(bridgeAdapter)
        );

        controller = new MockThemisController(address(router));
        controller.setCollateralToken(address(usdc));
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

    function testRevealBid_NotPlaced() public {
        controller.connectAuction(originDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(alice, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        address vault = controller.revealBid(alice, salt, nullProof());
        controller.revealBidCallback(alice, 100e6, salt, false);

        assertTrue(
            vault.code.length > 0,
            "Vault should be deployed"
        );
        assertEq(usdc.balanceOf(address(vault)), 0, "Vault should be empty");
        assertEq(
            usdc.balanceOf(alice),
            100_000e6,
            "Alice should get her bid amount refunded"
        );
    }

    function testRevealBid_Placed() public {
        controller.connectAuction(originDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(alice, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        address vault = controller.revealBid(alice, salt, nullProof());
        controller.revealBidCallback(alice, 100e6, salt, true);

        assertTrue(
            vault.code.length == 0,
            "Vault should not be deployed"
        );
        assertEq(usdc.balanceOf(address(vault)), 100e6, "Vault should be funded");
        assertEq(
            usdc.balanceOf(alice),
            99_900e6,
            "Alice should not get her bid amount refunded"
        );
    }

    function testRevealBid_DifferentBidder() public {
        controller.connectAuction(originDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(bob, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        address vault = controller.revealBid(bob, salt, nullProof());
        controller.revealBidCallback(bob, 100e6, salt, true);

        assertTrue(
            vault.code.length == 0,
            "Vault should not be deployed"
        );
        assertEq(usdc.balanceOf(address(vault)), 100e6, "Vault should be funded");
        assertEq(
            usdc.balanceOf(alice),
            99_900e6,
            "Alice should not get her bid amount refunded"
        );
    }

    function testDeployVaultOnReveal() public {
        controller.connectAuction(originDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(alice, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        address vault = controller.revealBid(alice, salt, nullProof());
        controller.revealBidCallback(alice, 100e6, salt, true);


        // TODO: fix this test
        // controller.deployVaultOnReveal(alice, 88e6, salt);

        assertTrue(
            vault.code.length == 0,
            "Vault should not be deployed"
        );

        // assertEq(
        //     usdc.balanceOf(alice),
        //     99_912e6,
        //     "Alice should balance refunded"
        // );

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
            address(usdc),
            from,
            salt
        );
        usdc.transfer(vault, bidValue);
    }

    function nullProof()
        private
        pure
        returns (ThemisController.CollateralizationProof memory proof)
    {
        return proof;
    }
}
