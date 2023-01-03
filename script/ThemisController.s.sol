// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";

import {ThemisController} from "src/ThemisController.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";

contract ControllerScript is Script {
    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

    address MUMBAI_MAILBOX = 0x1d3aAC239538e6F1831C8708803e61A9EA299Eec;
    uint32 MUMBAI_DOMAIN = 80001;
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
        AUCTION = stdJson.readAddress(json, ".contractAddress");
    }

    function run() public {
        setUp();

        vm.startBroadcast(pk);
        router = new ThemisRouter();
        router.initialize(
            MUMBAI_MAILBOX,
            MUMBAI_DOMAIN
        );
        controller = new ThemisController(address(router));
        // controller.connectAuction(domain_, contract_);
        vm.stopBroadcast();
    }
}
