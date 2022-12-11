

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

abstract contract BaseTest is Test {
    address constant internal MOONBASE_ALPHA_ICA =
        0x28DB114018576cF6c9A523C17903455A161d18C4;

    address constant alice = address(uint160(uint256(keccak256("alice"))));
    address constant bob = address(uint160(uint256(keccak256("bob"))));
    address constant charlie = address(uint160(uint256(keccak256("charlie"))));

    // not needed
    // uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
    // uint256 alice_pk = vm.envUint("ALICE_PRIVATE_KEY");
    // uint256 bob_pk = vm.envUint("BOB_PRIVATE_KEY");

    string goerliRPC = vm.envString("GOERLI_RPC_URL");
    uint256 originFork = vm.createFork(goerliRPC);

    string moonbaseRPC = vm.envString("MOONBASE_RPC_URL");
    uint256 remoteFork = vm.createFork(moonbaseRPC);

    uint32 originDomain = 5;                // goerli
    uint32 remoteDomain = 0x6d6f2d61;       // moonbase-alpa

    uint entropy = 0;

    function setUp() public virtual {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(charlie, "charlie");
    }

    function genBytes32() internal view returns (bytes32 salt) {
        return keccak256(abi.encodePacked(block.timestamp, entropy));
    }
}
