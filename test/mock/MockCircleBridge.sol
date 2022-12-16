// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {ICircleBridge} from "@hyperlane-xyz/core/contracts/middleware/liquidity-layer/interfaces/circle/ICircleBridge.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockCircleBridge is ICircleBridge {
    uint64 public nextNonce = 0;
    MockERC20 token;

    constructor(MockERC20 _token) {
        token = _token;
    }

    function depositForBurn(
        uint256 _amount,
        uint32,
        bytes32,
        address _burnToken
    ) external returns (uint64 _nonce) {
        nextNonce = nextNonce + 1;
        _nonce = nextNonce;
        require(address(token) == _burnToken);
        token.transferFrom(msg.sender, address(this), _amount);
        token.burn(_amount);
    }

    function depositForBurnWithCaller(
        uint256,
        uint32,
        bytes32,
        address,
        bytes32
    ) external returns (uint64 _nonce) {
        nextNonce = nextNonce + 1;
        _nonce = nextNonce;
    }
}
