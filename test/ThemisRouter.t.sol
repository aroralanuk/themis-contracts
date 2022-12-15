// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";

import {ThemisRouter} from "src/ThemisRouter.sol";

import {BaseTest} from "test/utils/BaseTest.sol";
import {MockHyperlaneEnvironment} from "test/mock/MockHyperlaneEnvironment.sol";
import {MockRecipient} from "test/mock/MockRecipient.sol";

contract ThemisRouterTest is BaseTest {
    error CallbackError();

    MockHyperlaneEnvironment testEnv;

    uint32 hubDomain = 1;
    uint32 spokeDomain = 2;

    ThemisRouter hubRouter;
    ThemisRouter spokeRouter;

    string bridge = "golden_gate";

    MockRecipient recipient;

    bool result = false;

    function setUp() public override {
        super.setUp();

        testEnv = new MockHyperlaneEnvironment(hubDomain, spokeDomain);

        hubRouter = new ThemisRouter();
        spokeRouter = new ThemisRouter();
        recipient = new MockRecipient();

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
        assertEq(result, true);
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

        assertEq(result, false);
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
        assertEq(result, false);
    }

    function exampleCallback(bool arg1, address arg2, uint128 arg3, bytes32 arg4) public {
        if (arg3 < 500e6) revert CallbackError();
        result = arg1 || arg2 == address(0x0) || arg3 %10 == 0 || arg4 == bytes32(0x0);
    }
}
