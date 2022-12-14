// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";

import {ThemisRouter} from "src/ThemisRouter.sol";

import {BaseTest} from "test/utils/BaseTest.sol";
import {MockHyperlaneEnvironment} from "test/mock/MockHyperlaneEnvironment.sol";
import {MockRecipient} from "test/mock/MockRecipient.sol";

contract ThemisRouterTest is BaseTest {
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
            TypeCasts.addressToBytes32(address(spokeRouter))
        );
    }

// function dispatchWithCallback(
//         uint32 _destinationDomain,
//         address _target,
//         bytes calldata data,
//         bytes calldata callback
//     )


    function testCallBack() public {
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
        testEnv.processNextPendingMessage();
    }

    function exampleCallback() public {
        result = true;
    }
}
