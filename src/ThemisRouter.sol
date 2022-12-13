// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Router} from "@hyperlane-xyz/core/contracts/Router.sol";

contract ThemisRouter is Router {
    // remote.dispatch -> origin.handle -> auction.checkBid -> origin.dispatch -> remote.handle -> vault.refund

    // auction.distribute -> origin.dispatch -> remote.handle -> remote.dispatchWithTokens -> origin.handleWithTokens -> auction.mint

    enum Action {
        DISPATCH,
        RESOLVE
    }

    event DispatchedWithCallback(
        uint32 destinationDomain,
        address sender,
        address target,
        bytes32 messageId
    );

    event HandledCall (
        address sender,
        address target,
        bytes data
    );

    struct Call {
        address to;
        bytes data;
        bytes callback;
    }

    function initialize(
        address _mailbox,
        address _interchainGasPaymaster,
        address _interchainSecurityModule
    ) public initializer {
        // Transfer ownership of the contract to `msg.sender`
        __HyperlaneConnectionClient_initialize(
            _mailbox,
            _interchainGasPaymaster,
            _interchainSecurityModule
        );
    }

    function dispatchWithCallback(
        uint32 _destinationDomain,
        address _target,
        bytes calldata data,
        bytes calldata callback
    ) internal returns (bytes32 messageId) {

        messageId = _dispatch(
            _destinationDomain,
            abi.encode(
                Action.DISPATCH,
                msg.sender,
                Call({to: _target, data: data, callback: callback})
            )
        );

        emit DispatchedWithCallback(
            _destinationDomain,
            msg.sender,
            _target,
            messageId
        );
    }

    function _handle(
        uint32 _origin,
        bytes32 /* _sender */,
        bytes calldata _message
    ) internal override {
        (Action action, address sender, Call memory call) = abi.decode(
            _message,
            (Action, address, Call)
        );

        if (action == Action.DISPATCH) {
            (bool success, bytes memory result) = call.to.call(call.data);

            require(
                success,
                _encodeError(result, call.to)
            );

            _dispatch(
                _origin,
                abi.encode(
                    Action.RESOLVE,
                    sender,
                    // fixme: call format
                    abi.encodeWithSelector(
                        bytes4(call.callback),
                        result
                    )
                )
            );

            emit HandledCall(sender, call.to, result);
        } else if (action == Action.RESOLVE) {
            // TODO: implement
        }
    }

    function _encodeError(bytes memory _result, address _to)
        internal pure returns (string memory)
    {
        return string(
            abi.encodePacked(
                "Call failed: ",
                _result,
                " for ",
                _to
            )
        );
    }
}
