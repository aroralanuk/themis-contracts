// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {ICircleMessageTransmitter} from "@hyperlane-xyz/core/contracts/middleware/liquidity-layer/interfaces/circle/ICircleMessageTransmitter.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockCircleMessageTransmitter is ICircleMessageTransmitter {
    mapping(bytes32 => bool) processedNonces;
    MockERC20 token;

    constructor(MockERC20 _token) {
        token = _token;
    }

    function receiveMessage(bytes memory, bytes calldata)
        external
        pure
        returns (bool success)
    {
        success = true;
    }

    function hashSourceAndNonce(uint32 _source, uint256 _nonce)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_source, _nonce));
    }

    function process(
        bytes32 _nonceId,
        address _recipient,
        uint256 _amount
    ) public {
        processedNonces[_nonceId] = true;
        token.mint(_recipient, _amount);
    }

    function usedNonces(bytes32 _nonceId) external view returns (bool) {
        return processedNonces[_nonceId];
    }
}
