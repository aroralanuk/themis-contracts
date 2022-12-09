// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Auction} from "src/lib/Auction.sol";

import {IThemis} from "src/IThemis.sol";
import {ThemisVault} from "src/ThemisVault.sol";

contract ThemisController is IThemis {

    bytes32 auction;
    mapping(address => bool) revealedVault;



    constructor(uint32 domain_, address contract_) {
        // query from
        auction = Auction.format(domain_, contract_);
    }

    function startReveal(
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

}
