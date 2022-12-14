// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "solmate/utils/SafeTransferLib.sol";
import {ThemisController} from "./ThemisController.sol";

/// @title A contract deployed via `CREATE2` by the `ThemisController` contract.
/// Bidders send their collateral to the address of the SneakyVault before it is deployed.
contract ThemisVault {
    using SafeTransferLib for ERC20;

    constructor(
        address token,
        address bidder,
        uint128 bidValue
    ) {
        // This contract should be deployed via `CREATE2` by a `ThemisController` contract
        ThemisController controller = ThemisController(msg.sender);
        // If this vault holds the collateral for the winning bid, send the bid amount
        // to the seller

        // TODO: fix this
        // if (controller.getHighestBidVault(auction, tokenId) == address(this)) {
        //     uint256 bidAmount = controller.getSecondHighestBid(tokenContract, tokenId);
        //     assert(address(this).balance >= bidAmount);
        //     controller.getSeller(tokenContract, tokenId).safeTransferETH(bidAmount);
        // }
        ERC20(token).safeTransfer(bidder, bidValue);
    }
}
