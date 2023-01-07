// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {ThemisController} from "src/ThemisController.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";

contract ControllerScript is Script {
    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

    uint32 MUMBAI_DOMAIN = 80001;
    address MUMBAI_MAILBOX = 0x1d3aAC239538e6F1831C8708803e61A9EA299Eec;
    address MUMBAI_ROUTER;

    uint32 GOERLI_DOMAIN = 5;
    address GOERLI_ROUTER;

    address AUCTION = 0x4E98A12ca0944588C915B8bCa911089e2726478b;
    // read auction contract from file

    ThemisController controller;
    ThemisRouter router;
    // function setUp() public {
    //     string memory path = string.concat(
    //         vm.projectRoot(),
    //         "/script/deploy/info.json"
    //     );
    //     string memory json = vm.readFile(path);
    //     AUCTION = stdJson.readAddress(json, ".contractAddress");
    //     GOERLI_ROUTER = stdJson.readAddress(json, ".goerliRouter");
    // }

    function run() public {
        // setUp();

        vm.startBroadcast(pk);
        router = new ThemisRouter();
        router.initialize(
            MUMBAI_MAILBOX,
            MUMBAI_DOMAIN
        );

        controller = new ThemisController(address(router));
        controller.connectAuction(5, AUCTION);
        vm.stopBroadcast();
    }

    // function enrollRouter() public {
    //     setUp();

    //     vm.startBroadcast(pk);
    //     router = ThemisRouter(MUMBAI_ROUTER);
    //     router.enrollRemoteRouter(
    //         GOERLI_DOMAIN,
    //         TypeCasts.addressToBytes32(GOERLI_ROUTER)
    //     );
    //     vm.stopBroadcast();
    // }
}
