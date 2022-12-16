// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ERC721} from "solmate/tokens/ERC721.sol";

import {Bids} from "src/lib/Bids.sol";

import {IThemis} from "src/IThemis.sol";

contract ThemisAuction is IThemis, ERC721 {
    using Bids for Bids.Heap;

    string public BASE_ASSET_URI;

    address public collectionOwner;

    uint256 public immutable MAX_SUPPLY;

    Bids.Heap public highestBids;

    uint64 public endOfBiddingPeriod;
    uint64 public endOfRevealPeriod;
    uint128 public reservePrice;

    mapping(uint256 => uint64) highestBid;
    mapping(uint256 => address) highestBidVault;
    mapping(uint256 => uint64) secondHighestBid;

    mapping(uint256 => address) public reserved;

    constructor (
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) ERC721(name_, symbol_) {
        collectionOwner = msg.sender;
        MAX_SUPPLY = maxSupply_;
    }

    function initialize(
        uint64 bidPeriod_,
        uint64 revealPeriod_,
        uint128 reservePrice_
    ) external {
        if (endOfBiddingPeriod != 0) revert AlreadyInitialized();

        endOfBiddingPeriod = uint64(block.timestamp) + bidPeriod_;
        endOfRevealPeriod =
            uint64(block.timestamp) + bidPeriod_ + revealPeriod_;
        reservePrice = reservePrice_;

        highestBids.initialize(uint32(MAX_SUPPLY));

        emit AuctionInitialized(
            address(this),
            msg.sender,
            bidPeriod_,
            revealPeriod_,
            reservePrice
        );
    }

    function checkBid(address bidder_, uint128 bidAmount_, bytes32 salt_) external returns (bool, address, uint128, bytes32){
        if (block.timestamp > endOfBiddingPeriod ||
        block.timestamp > endOfRevealPeriod) revert NotInRevealPeriod();
        if (bidAmount_ < reservePrice) revert BidLowerThanReserve();

        // insert in order of bids
        bool success = highestBids.insert(
            uint32(0xb1ba),
            bidder_,
            bidAmount_,
            uint64(block.timestamp) // fixme: use actual time
        );

        emit BidRevealed(
            address(this),
            bidder_,
            bidAmount_
        );

        return (success, bidder_, bidAmount_, salt_);
    }

    // TODO: later
    function lateRevealBid() external {}

    function endAuction() external {
        if (block.timestamp < endOfRevealPeriod) revert AuctionNotOver();

        Bids.Node memory bid;
        for (uint256 i = 0; i < highestBids.totalBids; i++) {
            bid = highestBids.index[highestBids.array[i]];

            // accountRouter call -> check for liquidity
            _reserve(bid.bidderAddress, i);
        }

        emit AuctionEnded();
    }

    function _reserve(address bidder_, uint256 id_) internal {
        reserved[id_] = bidder_;
    }


    function mint(uint256 id) external {
        _mint(msg.sender, id);
    }

    function _mint(address to, uint256 id) internal override {
        if (id >= MAX_SUPPLY) revert InvalidTokenId();
        if (reserved[id] != to) revert NotReserved();
        super._mint(to, id);
    }


    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(BASE_ASSET_URI, id));
    }
}
