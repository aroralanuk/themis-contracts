

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

abstract contract BaseTest is Test {
    address constant internal MOONBASE_ALPHA_ICA =
        0x28DB114018576cF6c9A523C17903455A161d18C4;

    uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
    uint256 alice_pk = vm.envUint("ALICE_PRIVATE_KEY");
    uint256 bob_pk = vm.envUint("BOB_PRIVATE_KEY");

    string moonbaseRPC = vm.envString("MOONBASE_RPC_URL");
    uint256 originFork = vm.createFork(moonbaseRPC);

    uint32 originDomain = 1;
    uint32 remoteDomain = 2;

    function switchBroadCast(uint key) internal {
        vm.stopBroadcast();
        vm.startBroadcast(key);
    }
}
