// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {Router} from "@hyperlane-xyz/core/contracts/Router.sol";
import {XAddress} from "src/lib/XAddress.sol";
import "src/lib/Utils.sol";
import {ILiquidityLayerRouter} from "./interfaces/ILiquidityLayerRouter.sol";
import {ILiquidityLayerAdapter} from "./interfaces/ILiquidityLayerAdapter.sol";
import {ILiquidityLayerMessageRecipient} from "./interfaces/ILiquidityLayerMessageRecipient.sol";

contract ThemisRouter is Router, ILiquidityLayerRouter  {
    using XAddress for XAddress.Info;
    // remote.dispatch -> origin.handle -> auction.checkBid -> origin.dispatch -> remote.handle -> vault.refund

    // auction.distribute -> origin.dispatch -> remote.handle -> remote.dispatchWithTokens -> origin.handleWithTokens -> auction.mint
    using TypeCasts for bytes32;
    using SafeTransferLib for ERC20;

    uint32 public DOMAIN;
    XAddress.Info public AUCTION_CONTRACT;
    address public ENDPOINT;

    XAddress.Info internal _address;

    enum Action {
        REVEAL_BID,
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

    function setEndpoint(address endpoint) external initializer {
        ENDPOINT = endpoint;
    }

    /**
     * @notice Register the address of a Router contract for the same Application on a remote chain
     * @param _domain The domain of the remote Application Router
     * @param _router The address of the remote Application Router
     */
    function enrollRemoteRouter(uint32 _domain, bytes32 _router)
        external
        virtual
        onlyOwner
        override
    {
        _enrollRemoteRouter(_domain, _router);
    }

    function dispatchRevealBid(
        address bidder,
        uint128 bidAmount,
        bytes32 salt
    ) external returns (bytes32 messageId) {

        _address.init(DOMAIN, bidder);

        messageId = _dispatch(
            AUCTION_CONTRACT.getDomain(),
            abi.encode(
                Action.REVEAL_BID,
                msg.sender,
                Call({
                    to: AUCTION_CONTRACT.getAddress(),
                    data: abi.encodeWithSignature("checkBid(bytes32,uint128",_address.toBytes32(), bidAmount)
                }),
                salt
            )
        );

        emit DispatchedWithCallback(
            AUCTION_CONTRACT.getDomain(),
            msg.sender,
            AUCTION_CONTRACT.getAddress(),
            messageId
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
                Call({to: _target, data: data})
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
        // console.log("transfer to the bridge adapter");
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

    event ReceivedMessage(uint32 origin, address sender, bytes message);

    function _handle(
        uint32 _origin,
        bytes32  _sender ,
        bytes calldata _message
    ) internal override {
        Action action = abi.decode(_message, (Action));

        // pattern match action type
        if (action == Action.REVEAL_BID) {
            // IF DISPATCH BID CALL
            // check for return true or false, reval or not
            ( , , Call memory call, bytes32 salt) = abi.decode(
                _message,
                (Action, address, Call, bytes32)
            );

            // call to checkBid()
            (bool success, bytes memory result) = call.to.call(call.data);

            // TODO: onlyTesting
            require(
                success,
                "ERROR: routing to auction failed"
            );

            success = success && abi.decode(result, (bool));

            bytes memory argData = extractCalldata(call.data);

            (bytes32 bidder, uint128 amount) = abi.decode(
                argData,
                (bytes32, uint128)
            );
            _address.init(bidder);

            if (!success) {
                ( success, ) = ENDPOINT.call(
                    abi.encodeWithSignature(
                        "revealBidCallback(address,uint128,bytes32,bool)",
                        _address.getAddress(),
                        amount,
                        salt,
                        false
                    )
                );
            } else {
                ( success, ) = ENDPOINT.call(
                    abi.encodeWithSignature(
                        "revealBidCallback(address,uint128,bytes32,bool)",
                        _address.getAddress(),
                        amount,
                        salt,
                        true
                    )
                );
            }

            console.logBytes(call.data);

            emit ReceivedMessage(_origin, call.to, _message);
        }
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

            emit HandledCall(sender, call.to, result);
        } else {
            emit HandledCall(TypeCasts.bytes32ToAddress(_sender), address(this), _message);
        }
        // } else if (action == Action.RESOLVE) {
        //     (, address sender, Call memory call) = abi.decode(
        //         _message,
        //         (Action, address, Call)
        //     );

        //     (bool success, bytes memory result) = call.to.call(call.data);

        //     require(
        //         success,
        //         "ERROR: origin callback failed"
        //     );

        //     emit HandledCallback(sender, call.to, result);
        // } else if (action == Action.LIQUIDITY) {
        //     (
        //         , LiquidityData memory liqData
        //     ) = abi.decode(
        //             _message,
        //             (Action, LiquidityData)
        //     );

        //     ILiquidityLayerMessageRecipient _userRecipient
        //         = ILiquidityLayerMessageRecipient(
        //         TypeCasts.bytes32ToAddress(liqData.recipient)
        //     );

        //     // Reverts if the adapter hasn't received the bridged tokens yet
        //     (address _token, uint256 _receivedAmount) = _getAdapter(liqData.bridge)
        //         .receiveTokens(
        //             _origin,
        //             address(_userRecipient),
        //             liqData.amount,
        //             liqData.adapterData
        //     );

        //     _userRecipient.handleWithTokens(
        //         _origin,
        //         liqData.sender,
        //         liqData.messageBody,
        //         _token,
        //         _receivedAmount
        //     );
        // }
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
