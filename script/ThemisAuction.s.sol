// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";


contract AuctionScript is Script {

    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

    address GOERLI_MAILBOX = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;
    uint32 GOERLI_DOMAIN = 5;
    address GOERLI_ROUTER;

    uint32 MUMBAI_DOMAIN = 80001;
    address MUMBAI_ROUTER;

    ThemisAuction auction;


    function run() public {
        vm.startBroadcast(pk);

        auction = new ThemisAuction("Ethereal Encounters", "EE", 100);

        vm.stopBroadcast();
    }
}
