// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";

import {ThemisAuction} from "src/ThemisAuction.sol";

contract ThemisScript is Script {
    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

    ThemisAuction auction;
    function setUp() public {}

    function run() public {
        vm.broadcast(pk);
        console.log(vm.addr(pk));

        auction = new ThemisAuction("Ethereal Encounters", "EE", 10_000);

        vm.stopBroadcast();
    }
}
