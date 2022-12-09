// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

library Auction {
    function format(uint32 domain_, address auctionAddress_)
        internal
        pure
        returns (bytes32 auction)
    {
        auction = bytes32(uint256(domain_) << 160 | uint160(auctionAddress_));
    }

    function getDomain(bytes32 auction_) internal pure returns (uint32 domain) {
        domain = uint32(uint256(auction_) >> 160);
    }

    function getAuctionAddress(bytes32 auction_) internal pure returns (address auctionAddress_) {
        auctionAddress_ = address(uint160(uint256(auction_)));
    }
}
