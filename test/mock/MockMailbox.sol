// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {IMessageRecipient} from "@hyperlane-xyz/core/interfaces/IMessageRecipient.sol";

import "forge-std/console.sol";

contract MockMailbox {
    using TypeCasts for address;
    using TypeCasts for bytes32;
    // Domain of chain on which the contract is deployed
    uint32 public immutable domain;
    uint32 public immutable version = 0;

    uint256 public outboundNonce = 0;
    uint256 public inboundUnprocessedNonce = 0;
    uint256 public inboundProcessedNonce = 0;
    mapping(uint32 => MockMailbox) public remoteMailboxes;
    mapping(uint256 => Message) public inboundMessages;

    struct Message {
        uint32 origin;
        address sender;
        address recipient;
        bytes body;
    }

    constructor(uint32 _domain) {
        domain = _domain;
    }

    function addRemoteMailbox(uint32 _domain, MockMailbox _mailbox) external {
        remoteMailboxes[_domain] = _mailbox;
    }

    function dispatch(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        bytes calldata _messageBody
    ) external returns (bytes32) {
        MockMailbox _destinationMailbox = remoteMailboxes[_destinationDomain];
        require(
            address(_destinationMailbox) != address(0),
            "Missing remote mailbox"
        );
        _destinationMailbox.addInboundMessage(
            domain,
            msg.sender,
            _recipientAddress.bytes32ToAddress(),
            _messageBody
        );
        outboundNonce++;
        return bytes32(0);
    }

    function addInboundMessage(
        uint32 _origin,
        address _sender,
        address _recipient,
        bytes calldata _body
    ) external {
        inboundMessages[inboundUnprocessedNonce] = Message(
            _origin,
            _sender,
            _recipient,
            _body
        );
        inboundUnprocessedNonce++;
    }

    function processNextInboundMessage() public {
        Message memory _message = inboundMessages[inboundProcessedNonce];

        IMessageRecipient(_message.recipient).handle(
            _message.origin,
            _message.sender.addressToBytes32(),
            _message.body
        );
        inboundProcessedNonce++;
    }
}
