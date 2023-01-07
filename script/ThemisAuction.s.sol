// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";


contract AuctionScript is Script {
    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

    address GOERLI_MAILBOX = 0x1d3aAC239538e6F1831C8708803e61A9EA299Eec;
    uint32 GOERLI_DOMAIN = 5;
    address GOERLI_ROUTER;

    uint32 MUMBAI_DOMAIN = 80001;
    address MUMBAI_ROUTER;

    ThemisAuction auction;
    ThemisRouter router;
    // function setUp() public {
    //     string memory path = string.concat(
    //         vm.projectRoot(),
    //         "/script/deploy/info.json"
    //     );
    //     string memory json = vm.readFile(path);

    //     MUMBAI_ROUTER = stdJson.readAddress(json, ".mumbaiRouter");
    //     GOERLI_ROUTER = stdJson.readAddress(json, ".goerliRouter");
    // }

    function run() public {
        vm.startBroadcast(pk);

        auction = new ThemisAuction("Ethereal Encounters", "EE", 100);
        router = new ThemisRouter();
        router.initialize(
            GOERLI_MAILBOX,
            GOERLI_DOMAIN
        );
        vm.stopBroadcast();
    }

    // function enrollRouter() public {
    //     setUp();

    //     vm.startBroadcast(pk);
    //     router = ThemisRouter(GOERLI_ROUTER);
    //     router.enrollRemoteRouter(
    //         MUMBAI_DOMAIN,
    //         TypeCasts.addressToBytes32(MUMBAI_ROUTER)
    //     );
    //     vm.stopBroadcast();
    // }
}
