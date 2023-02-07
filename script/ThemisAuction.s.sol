// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";


contract AuctionScript is Script {

    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

    address GOERLI_USDC = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;

    ThemisAuction auction;

    function run() public {
        vm.startBroadcast(pk);

        auction = new ThemisAuction("Ethereal Encounters", "EE", 100);
        auction.setCollateralToken(GOERLI_USDC);

        auction.initialize(
            uint64(5 minutes),
            uint64(2 hours),
            uint128(5e5)
        );

        vm.stopBroadcast();
    }
}
