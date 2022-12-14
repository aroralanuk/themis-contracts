// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

contract MockRecipient {
    bool test = false;

    error SenderZeroAddress();

    function exampleFunction(address arg1, uint128 arg2, bytes32 arg3) external returns (bool, address, uint128, bytes32) {
        if (arg1 == address(0x0)) {
            revert SenderZeroAddress();
        }
        test = arg1 == address(0x0) || arg2 %10 == 0 || arg3 == bytes32(0x0);
        return (true, arg1, arg2, arg3);
    }

    // function testICA(address bidder_, uint128 amt) external returns (bool) {
    //     return true;
    // }

    // TODO: later
    // function exampleFunction() external {}

}
