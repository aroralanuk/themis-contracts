pragma solidity ^0.8.15;

import "./LibBalanceProof.sol";

contract TokenBalanceProof {
    function getBalance(
        address token,
        address holder,
        uint256 blockNumber,
        bytes[] memory proof,
        uint256 basePosition
    ) public view returns (uint balance) {
        uint256 slot = uint256(
            keccak256(abi.encodePacked(holder, uint256(basePosition)))
        );

        balance = 0;
    }
}
