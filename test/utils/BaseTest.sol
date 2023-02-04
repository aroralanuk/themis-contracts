

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

abstract contract BaseTest is Test {

    uint128 constant USDC = 1e6;

    address constant alice = address(uint160(uint256(keccak256("alice"))));
    address constant bob = address(uint160(uint256(keccak256("bob"))));
    address constant charlie = address(uint160(uint256(keccak256("charlie"))));
    address constant devin = address(uint160(uint256(keccak256("devin"))));
    address constant ellie = address(uint160(uint256(keccak256("ellie"))));

    address[] testUsers = [alice, bob, charlie, devin];
    uint128[] testBids = [200e6, 150e6, 120e6, 90e6];
    bytes32[] testSalts = [bytes32(uint256(200)), bytes32(uint256(150)), bytes32(uint256(120)), bytes32(uint256(90))];


    uint32[] testLesserKey = [0, 0, 0, 0];
    uint32[] testGreaterKey = [0, 1, 2, 3];

    bytes32 salt;

    // placeholder for now
    address[] expectedUsers = [alice, alice, alice];
    uint32[] expectedDomains = [0, 0, 0];
    uint128[] expectedBids = [0, 0, 0];

    string goerliRPC = vm.envString("GOERLI_RPC_URL");
    uint256 originFork = vm.createFork(goerliRPC);

    uint entropy = 0;

    MockERC20 internal usdc;

    function setUp() public virtual {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(charlie, "charlie");
        vm.label(devin, "devin");
        vm.label(ellie, "ellie");

        usdc = new MockERC20("USDC", "USDC", 6);

        usdc.mint(address(this), 100_000e6);
        usdc.mint(alice, 100_000e6);
        usdc.mint(bob, 100_000e6);
        usdc.mint(charlie, 100_000e6);
        usdc.mint(devin, 100_000e6);
        usdc.mint(ellie, 100_000e6);
    }

    function genBytes32() internal returns (bytes32) {
        entropy++;
        return keccak256(abi.encodePacked(block.timestamp, entropy));
    }
}
