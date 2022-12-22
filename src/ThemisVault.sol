// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ThemisController} from "./ThemisController.sol";

/// @title A contract deployed via `CREATE2` by the `ThemisController` contract.
/// Bidders send their collateral to the address of the SneakyVault before it is deployed.
contract ThemisVault {
    using SafeTransferLib for ERC20;

    uint32 transferReceipt;

    constructor(
        bytes32 /* auction */,
        address collateralToken,
        address bidder
    ) {
        // TODO: This contract should be deployed via `CREATE2` by a `ThemisController` contract
        ThemisController controller = ThemisController(msg.sender);
        // TODO: check valid  auction

        // If this vault holds the collateral for the winning bid, send the
        // bid amount to the control
        uint256 bidAmount = controller.getBidRequired(bidder);
        ERC20(collateralToken).transfer(address(controller), bidAmount);

        uint balance = ERC20(collateralToken).balanceOf(address(this)) - bidAmount;
        ERC20(collateralToken).safeTransfer(bidder, balance);

        transferReceipt = 1;
    }

    function getLiquidityReceipt() external view returns (uint32) {
        return transferReceipt;
    }
}
