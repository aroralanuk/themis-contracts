// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Auction} from "src/lib/Auction.sol";

import {IThemis} from "src/IThemis.sol";
import {ThemisVault} from "src/ThemisVault.sol";

contract ThemisController is IThemis {


    bytes32 auction;
    mapping(address => bool) revealedVault;

    uint32 domain;
    uint96 revealStartBlock;
    bytes32 storedBlockHash;


    constructor(uint32 domain_, address contract_) {
        // query from
        auction = Auction.format(domain_, contract_);
    }

    function startReveal() external {
        if (storedBlockHash != bytes32(0)) revert RevealAlreadyStarted();
        uint256 revealStartBlockCached = revealStartBlock;
        if (block.number <= revealStartBlockCached) revert NotYetRevealBlock();
        storedBlockHash = blockhash(
            max(block.number - 256, revealStartBlockCached)
        );
        // overwrite reveal start block
        revealStartBlock = uint96(block.number);
        emit RevealStarted();
    }

    function reveal(
        address bidder_,
        uint128 bidAmount_,
        bytes32 salt_
    ) external {
        address vault = getVaultAddress(
            auction,
            bidder_,
            bidAmount_,
            salt_
        );

        if (revealedVault[vault]) revert BidAlreadyRevealed();
        revealedVault[vault] = true;


    }

    function getVaultAddress(
        bytes32 auction_,
        address bidder_,
        uint128 bidAmount_,
        bytes32 salt_
    ) public view returns (address vault) {
        // Compute `CREATE2` address of vault
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt_,
            keccak256(abi.encodePacked(
                type(ThemisVault).creationCode,
                abi.encode(
                    auction_,
                    bidder_,
                    bidAmount_
                )
            ))
        )))));
    }

    function _getProvenVaultBalance() external {}

    function max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }
}
