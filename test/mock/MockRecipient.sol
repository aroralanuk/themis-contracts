// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";
import {ILiquidityLayerMessageRecipient} from "@hyperlane-xyz/core/interfaces/ILiquidityLayerMessageRecipient.sol";

contract MockRecipient is ILiquidityLayerMessageRecipient {
    bool test = false;


    bytes32 public lastSender;
    bytes public lastData;
    address public lastToken;
    uint256 public lastAmount;

    address public lastCaller;
    string public lastCallMessage;

    event ReceivedMessage(
        uint32 indexed origin,
        bytes32 indexed sender,
        string message,
        address token,
        uint256 amount
    );

    event ReceivedCall(address indexed caller, uint256 amount, string message);

    error SenderZeroAddress();

    function exampleFunction(address arg1, uint128 arg2, bytes32 arg3) external returns (bool, address, uint128, bytes32) {
        if (arg1 == address(0x0)) {
            revert SenderZeroAddress();
        }
        test = arg1 == address(0x0) || arg2 %10 == 0 || arg3 == bytes32(0x0);
        return (true, arg1, arg2, arg3);
    }

    function handleWithTokens(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _data,
        address _token,
        uint256 _amount
    ) external override {
        emit ReceivedMessage(_origin, _sender, string(_data), _token, _amount);
        lastSender = _sender;
        lastData = _data;
        lastToken = _token;
        lastAmount = _amount;
    }
}
