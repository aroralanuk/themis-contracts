// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.15;

import "./MockMailbox.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";

// simplified version of @hyperlane-xyz's MockHyperlaneEnvironment only for mailbox
contract MockHyperlaneEnvironment {
    uint32 originDomain;
    uint32 destinationDomain;

    mapping(uint32 => MockMailbox) public mailboxes;

    constructor(uint32 _originDomain, uint32 _destinationDomain) {
        originDomain = _originDomain;
        destinationDomain = _destinationDomain;

        MockMailbox originMailbox = new MockMailbox(_originDomain);
        MockMailbox destinationMailbox = new MockMailbox(_destinationDomain);

        originMailbox.addRemoteMailbox(_destinationDomain, destinationMailbox);
        destinationMailbox.addRemoteMailbox(_originDomain, originMailbox);

        mailboxes[_originDomain] = originMailbox;
        mailboxes[_destinationDomain] = destinationMailbox;
    }

    function processNextPendingMessage() public {
        mailboxes[destinationDomain].processNextInboundMessage();
    }

    function processNextPendingMessageFromDestination() public {
        mailboxes[originDomain].processNextInboundMessage();
    }
}
