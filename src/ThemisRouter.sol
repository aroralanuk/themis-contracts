// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {Router} from "@hyperlane-xyz/core/contracts/Router.sol";
import {ILiquidityLayerRouter} from "./interfaces/ILiquidityLayerRouter.sol";
import {ILiquidityLayerAdapter} from "./interfaces/ILiquidityLayerAdapter.sol";
import {ILiquidityLayerMessageRecipient} from "./interfaces/ILiquidityLayerMessageRecipient.sol";

contract ThemisRouter is Router, ILiquidityLayerRouter  {
    // remote.dispatch -> origin.handle -> auction.checkBid -> origin.dispatch -> remote.handle -> vault.refund

    // auction.distribute -> origin.dispatch -> remote.handle -> remote.dispatchWithTokens -> origin.handleWithTokens -> auction.mint
    using TypeCasts for bytes32;
    using SafeERC20 for IERC20;

    enum Action {
        DISPATCH,
        LIQUIDITY,
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

    mapping(string => address) public liquidityLayerAdapters;

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
        IERC20(_token).safeTransferFrom(
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

        if (action == Action.DISPATCH) {

            (, address sender, Call memory call) = abi.decode(
                _message,
                (Action, address, Call)
            );
            (bool success, bytes memory result) = call.to.call(call.data);

            require(
                success,
                _encodeError(result, call.to)
            );

            _dispatch(
                _origin,
                abi.encode(
                    Action.RESOLVE,
                    address(this),
                    Call({
                        to: sender,
                        data: abi.encodeWithSelector(
                            bytes4(call.callback),
                            result
                        ),
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
                _encodeError(result, call.to)
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

    function _getAdapter(string memory _bridge)
        internal
        view
        returns (ILiquidityLayerAdapter _adapter)
    {
        _adapter = ILiquidityLayerAdapter(liquidityLayerAdapters[_bridge]);
        // Require the adapter to have been set
        require(address(_adapter) != address(0), "No adapter found for bridge");
    }
}
