// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {ThemisController} from "src/ThemisController.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";

contract ControllerScript is Script {
    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

    uint32 MUMBAI_DOMAIN = 80001;
    address MUMBAI_MAILBOX = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;
    address MUMBAI_ROUTER;

    uint32 GOERLI_DOMAIN = 5;
    address GOERLI_ROUTER;

    address AUCTION;
    // read auction contract from file

    ThemisController controller;
    ThemisRouter router;

    function setUp() public {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/deploy/info.json"
        );
        string memory json = vm.readFile(path);
        console.log(AUCTION);
        AUCTION = stdJson.readAddress(json, ".goerliAuction");
    }

    function run() public {
        setUp();

        vm.startBroadcast(pk);
        router = new ThemisRouter{salt: TypeCasts.addressToBytes32(AUCTION)}();
        router.initialize(
            MUMBAI_MAILBOX,
            MUMBAI_DOMAIN
        );
        controller = new ThemisController(address(router));
        controller.connectAuction(5, AUCTION);
        router.setEndpoint(address(controller));
        vm.stopBroadcast();
    }
}
