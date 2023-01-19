// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";


contract AuctionScript is Script {
    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

    address GOERLI_MAILBOX = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;
    uint32 GOERLI_DOMAIN = 5;
    address GOERLI_ROUTER;

    uint32 MUMBAI_DOMAIN = 80001;
    address MUMBAI_ROUTER;

    ThemisAuction auction;
    ThemisRouter router;

    function run() public {
        vm.startBroadcast(pk);

        auction = new ThemisAuction("Ethereal Encounters", "EE", 100);
        router = new ThemisRouter
            {salt: TypeCasts.addressToBytes32(address(auction)) }();
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
