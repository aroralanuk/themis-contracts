// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

contract MockRecipient {
    bool test = false;

    function exampleFunction(address arg1, uint128 arg2, bytes32 arg3) external {
        test = true;
        console.log("rec works");
    }

    // function testICA(address bidder_, uint128 amt) external returns (bool) {
    //     return true;
    // }

    // TODO: later
    // function exampleFunction() external {}

}
