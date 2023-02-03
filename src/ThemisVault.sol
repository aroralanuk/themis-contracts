// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";

/// @title A contract deployed via `CREATE2` by the `ThemisController` contract.
/// Bidders send their collateral to the address of the SneakyVault before it is deployed.
contract ThemisVault {
    using SafeTransferLib for ERC20;

    uint32 transferReceipt;

    constructor(
        address tokenContract,
        address collateralToken,
        address bidder
    ) {
        // TODO: This contract should be deployed via `CREATE2` by a `ThemisController` contract
        ThemisAuction auction = ThemisAuction(msg.sender);
        // TODO: check valid  auction

        // If this vault holds the collateral for the winning bid, send the
        // bid amount to the control
        uint128 bidAmount = auction.bidAmounts(bidder);
        ERC20(collateralToken).transfer(address(auction), bidAmount);

        uint256 balance = ERC20(collateralToken).balanceOf(address(this));
        ERC20(collateralToken).transfer(bidder, balance);

        console.log("SneakyVault deployed add:", collateralToken );
        console.log("SneakyVault deployed bal:", ERC20(collateralToken).balanceOf(address(this)) );

        transferReceipt = 1;
    }

    function getLiquidityReceipt() external view returns (uint32) {
        return transferReceipt;
    }
}
