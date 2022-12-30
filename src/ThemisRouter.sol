// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {Router} from "@hyperlane-xyz/core/contracts/Router.sol";
import {ILiquidityLayerRouter} from "./interfaces/ILiquidityLayerRouter.sol";
import {ILiquidityLayerAdapter} from "./interfaces/ILiquidityLayerAdapter.sol";
import {ILiquidityLayerMessageRecipient} from "./interfaces/ILiquidityLayerMessageRecipient.sol";

contract ThemisRouter is Router, ILiquidityLayerRouter  {
    // remote.dispatch -> origin.handle -> auction.checkBid -> origin.dispatch -> remote.handle -> vault.refund

    // auction.distribute -> origin.dispatch -> remote.handle -> remote.dispatchWithTokens -> origin.handleWithTokens -> auction.mint
    using TypeCasts for bytes32;
    using SafeTransferLib for ERC20;

    uint32 public DOMAIN;
    enum Action {
        DISPATCH,
        LIQUIDITY,
        RESOLVE
    }

    mapping(string => address) public liquidityLayerAdapters;

    event LiquidityLayerAdapterSet(string indexed bridge, address adapter);

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

    event HandledCallback (
        address sender,
        address target,
        bytes data
    );

    struct Call {
        address to;
        bytes data;
        bytes callback;
    }

    struct LiquidityData {
        bytes32 sender;
        bytes32 recipient;
        uint256 amount;
        string bridge;
        bytes adapterData;
        bytes messageBody;
    }



    function initialize(address mailbox, uint32 domain) public initializer {
        // Transfer ownership of the contract to `msg.sender`
        __HyperlaneConnectionClient_initialize(mailbox);
        // hyperlane domain for this chain
        DOMAIN = domain;
    }

    function dispatchWithCallback(
        uint32 _destinationDomain,
        address _target,
        bytes calldata data,
        bytes calldata callback
    ) external returns (bytes32 messageId) {
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

    function dispatchWithTokens(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        bytes calldata _messageBody,
        address _token,
        uint256 _amount,
        string calldata _bridge
    ) external payable returns (bytes32) {
        ILiquidityLayerAdapter _adapter = _getAdapter(_bridge);

        // transfer to the bridge adapter
        console.log("transfer to the bridge adapter");
        ERC20(_token).transferFrom(
                msg.sender,
                address(_adapter),
                _amount
        );

        // Reverts if the bridge was unsuccessful.
        // Gets adapter-specific data that is encoded into the message
        // ultimately sent via Hyperlane.
        bytes memory _adapterData = _adapter.sendTokens(
            _destinationDomain,
            _recipientAddress,
            _token,
            _amount
        );

        // The user's message "wrapped" with metadata required by this middleware
        bytes memory _messageWithMetadata = abi.encode(
            Action.LIQUIDITY,
            LiquidityData({
                sender: TypeCasts.addressToBytes32(msg.sender),
                recipient: _recipientAddress, // The "user" recipient
                amount: _amount, // The amount of the tokens sent over the bridge
                bridge: _bridge, // The destination token bridge ID
                adapterData: _adapterData, // The adapter-specific data
                messageBody: _messageBody // The "user" message
            })
        );

        // Dispatch the _messageWithMetadata to the destination's LiquidityLayerRouter.
        return _dispatch(
            _destinationDomain,
            _messageWithMetadata
        );
    }




    function _handle(
        uint32 _origin,
        bytes32 /* _sender */,
        bytes calldata _message
    ) internal override {
        Action action = abi.decode(_message, (Action));

        // pattern match action type
        if (action == Action.DISPATCH) {

            (, address sender, Call memory call) = abi.decode(
                _message,
                (Action, address, Call)
            );
            (bool success, bytes memory result) = call.to.call(call.data);

            require(
                success,
                "ERROR: destination call failed"
            );

            _dispatch(
                _origin,
                abi.encode(
                    Action.RESOLVE,
                    address(this),
                    Call({
                        to: sender,
                        data: bytes.concat(call.callback, result),
                        callback: "0x00"
                    })
                )
            );

            emit HandledCall(sender, call.to, result);
        } else if (action == Action.RESOLVE) {
            (, address sender, Call memory call) = abi.decode(
                _message,
                (Action, address, Call)
            );

            (bool success, bytes memory result) = call.to.call(call.data);

            require(
                success,
                "ERROR: origin callback failed"
            );

            emit HandledCallback(sender, call.to, result);
        } else if (action == Action.LIQUIDITY) {
            (
                , LiquidityData memory liqData
            ) = abi.decode(
                    _message,
                    (Action, LiquidityData)
            );

            ILiquidityLayerMessageRecipient _userRecipient
                = ILiquidityLayerMessageRecipient(
                TypeCasts.bytes32ToAddress(liqData.recipient)
            );

            // Reverts if the adapter hasn't received the bridged tokens yet
            (address _token, uint256 _receivedAmount) = _getAdapter(liqData.bridge)
                .receiveTokens(
                    _origin,
                    address(_userRecipient),
                    liqData.amount,
                    liqData.adapterData
            );

            _userRecipient.handleWithTokens(
                _origin,
                liqData.sender,
                liqData.messageBody,
                _token,
                _receivedAmount
            );
        }
    }

    function setLiquidityLayerAdapter(string calldata _bridge, address _adapter)
        external
        onlyOwner
    {
        liquidityLayerAdapters[_bridge] = _adapter;
        emit LiquidityLayerAdapterSet(_bridge, _adapter);
    }

    function getDomain() external view returns (uint32) {
        return DOMAIN;
    }

    function _getAdapter(string memory _bridge)
        public
        view
        returns (ILiquidityLayerAdapter _adapter)
    {
        _adapter = ILiquidityLayerAdapter(liquidityLayerAdapters[_bridge]);
        // Require the adapter to have been set
        require(address(_adapter) != address(0), "No adapter found for bridge");
    }
}
