// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {CircleBridgeAdapter} from "@hyperlane-xyz/core/contracts/middleware/liquidity-layer/adapters/CircleBridgeAdapter.sol";

import {ThemisRouter} from "src/ThemisRouter.sol";

import {BaseTest} from "test/utils/BaseTest.sol";
import {MockHyperlaneEnvironment} from "test/mock/MockHyperlaneEnvironment.sol";
import {MockRecipient} from "test/mock/MockRecipient.sol";
import {MockCircleBridge} from "test/mock/MockCircleBridge.sol";
import {MockCircleMessageTransmitter} from "test/mock/MockCircleMessageTransmitter.sol";

contract ThemisRouterTest is BaseTest {
    error CallbackError();

    MockHyperlaneEnvironment testEnv;

    uint32 hubDomain = 1;
    uint32 spokeDomain = 2;

    ThemisRouter hubRouter;
    ThemisRouter spokeRouter;

    string bridge = "golden_gate";
    CircleBridgeAdapter hubBridgeAdapter;
    CircleBridgeAdapter spokeBridgeAdapter;

    MockRecipient recipient;
    MockCircleBridge circleBridge;
    MockCircleMessageTransmitter messageTransmitter;

    bool callbackResult = false;
    event LiquidityLayerAdapterSet(string indexed bridge, address adapter);

    function setUp() public override {
        super.setUp();

        testEnv = new MockHyperlaneEnvironment(hubDomain, spokeDomain);

        hubRouter = new ThemisRouter();
        spokeRouter = new ThemisRouter();
        recipient = new MockRecipient();

        circleBridge = new MockCircleBridge(usdc);
        messageTransmitter = new MockCircleMessageTransmitter(usdc);
        hubBridgeAdapter = new CircleBridgeAdapter();
        spokeBridgeAdapter = new CircleBridgeAdapter();

        hubRouter.initialize(
            address(testEnv.mailboxes(hubDomain))
        );

        spokeRouter.initialize(
            address(testEnv.mailboxes(spokeDomain))
        );

        hubRouter.enrollRemoteRouter(
            spokeDomain,
            TypeCasts.addressToBytes32(address(spokeRouter))
        );

        spokeRouter.enrollRemoteRouter(
            hubDomain,
            TypeCasts.addressToBytes32(address(hubRouter))
        );

        hubBridgeAdapter.initialize(
            address(this),
            address(circleBridge),
            address(messageTransmitter),
            address(hubRouter)
        );

        hubRouter.setLiquidityLayerAdapter(
            bridge,
            address(hubBridgeAdapter)
        );

        spokeRouter.setLiquidityLayerAdapter(
            bridge,
            address(spokeBridgeAdapter)
        );
    }

    function testCallBack() public {
        bytes32 _salt = genBytes32();

        spokeRouter.dispatchWithCallback(
            hubDomain,
            address(recipient),
            abi.encodeCall(
                recipient.exampleFunction,
                (address(this), 1000e6, _salt)
            ),
            abi.encodePacked(this.exampleCallback.selector)
        );
        testEnv.processNextPendingMessageFromDestination();
        testEnv.processNextPendingMessage();
        assertEq(callbackResult, true);
    }

    function testCallRevert() public {
        bytes32 _salt = genBytes32();

        spokeRouter.dispatchWithCallback(
            hubDomain,
            address(recipient),
            abi.encodeCall(
                recipient.exampleFunction,
                (address(0x0), 1000e6, _salt)
            ),
            abi.encodePacked(this.exampleCallback.selector)
        );

        vm.expectRevert();
        testEnv.processNextPendingMessageFromDestination();

        assertEq(callbackResult, false);
    }

    function testCallbackRevert() public {
        bytes32 _salt = genBytes32();

        spokeRouter.dispatchWithCallback(
            hubDomain,
            address(recipient),
            abi.encodeCall(
                recipient.exampleFunction,
                (address(this), 100e6, _salt)
            ),
            abi.encodePacked(this.exampleCallback.selector)
        );

        testEnv.processNextPendingMessageFromDestination();
        vm.expectRevert();
        testEnv.processNextPendingMessage();
        assertEq(callbackResult, false);
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDITY LAYER TESTING
    //////////////////////////////////////////////////////////////*/

    function testChangeLiquidityAdapter() public {
        vm.expectEmit(true, false, false, true);
        emit LiquidityLayerAdapterSet("brooklyn_bridge", address(spokeBridgeAdapter));

        spokeRouter.setLiquidityLayerAdapter(
            "brooklyn_bridge",
            address(spokeBridgeAdapter)
        );

        // Expect the bridge adapter to have been set
        assertEq(
            spokeRouter.liquidityLayerAdapters("brooklyn_bridge"),
            address(spokeBridgeAdapter)
        );

    }

    function testDispatchTokens_UnkownBridgeAdapter_Fail() public {
        spokeRouter._getAdapter(bridge);
        vm.expectRevert("No adapter found for bridge");
        spokeRouter.dispatchWithTokens(
            hubDomain,
            TypeCasts.addressToBytes32(address(recipient)),
            hex"0e23419f",
            address(usdc),
            100e6,
            "BazBridge" // some unknown bridge name
        );
    }

    function testDispatchTokens_InsufficientAllowance_Fail() public {
        // solmate tries subtracting the amount from allowance, which gives a
        // arithmetic underflow instead of insufficient allowance error
        vm.expectRevert();
        spokeRouter.dispatchWithTokens(
            hubDomain,
            TypeCasts.addressToBytes32(address(recipient)),
            hex"0e23419f",
            address(usdc),
            100e6,
            bridge
        );
    }

    function testDispatchWithTokenTransfersMovesTokens() public {
        usdc.approve(address(spokeRouter), 100e6);
        // TODO: fix this test
        vm.expectRevert();
        spokeRouter.dispatchWithTokens(
            hubDomain,
            TypeCasts.addressToBytes32(address(recipient)),
            hex"0e23419f",
            address(usdc),
            100e6,
            bridge
        );
    }

    function exampleCallback(bool arg1, address arg2, uint128 arg3, bytes32 arg4) public {
        if (arg3 < 500e6) revert CallbackError();
        callbackResult = arg1 || arg2 == address(0x0) || arg3 %10 == 0 || arg4 == bytes32(0x0);
    }
}
