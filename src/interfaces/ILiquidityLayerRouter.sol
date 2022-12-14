// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.11;


// author: @hyperlane-xyz
interface ILiquidityLayerRouter {
    function dispatchWithTokens(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        bytes calldata _messageBody,
        address _token,
        uint256 _amount,
        string calldata _bridge
    ) external payable returns (bytes32);
}
