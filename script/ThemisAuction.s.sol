// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";

import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";

contract AuctionScript is Script {
    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

    address GOERLI_MAILBOX = 0x1d3aAC239538e6F1831C8708803e61A9EA299Eec;
    uint32 GOERLI_DOMAIN = 5;

    ThemisAuction auction;
    ThemisRouter router;
    function setUp() public {}

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
}
