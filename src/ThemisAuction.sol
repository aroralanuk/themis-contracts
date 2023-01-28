// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// import "forge-std/console.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ILiquidityLayerMessageRecipient} from "@hyperlane-xyz/core/interfaces/ILiquidityLayerMessageRecipient.sol";

import {Bids} from "src/lib/Bids.sol";
import {XAddress} from "src/lib/XAddress.sol";
import {IThemis} from "src/IThemis.sol";
import {ThemisController} from "src/ThemisController.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";

contract ThemisAuction is IThemis, ERC721, ILiquidityLayerMessageRecipient {
    using XAddress for XAddress.Info;
    using Bids for Bids.Heap;

    string public BASE_ASSET_URI;

    address public collectionOwner;

    uint256 public immutable MAX_SUPPLY;

    Bids.Heap public highestBids;
    XAddress.Info internal _bidder;

    uint64 public endOfBiddingPeriod;
    uint64 public endOfRevealPeriod;
    uint128 public reservePrice;

    mapping (uint32 => address) public controllers;
    mapping(uint256 => address) public reserved;

    ThemisRouter public router;
    address public ROUTER_ADDRESS;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor (
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) ERC721(name_, symbol_) {
        collectionOwner = msg.sender;
        MAX_SUPPLY = maxSupply_;
        collectionOwner = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != collectionOwner) revert NotCollectionOwner();
        _;
    }

    modifier onlyRouter() {
        if (msg.sender != ROUTER_ADDRESS) revert NotRouter();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               ROUTER HANDLING
    //////////////////////////////////////////////////////////////*/

    function setRouter(address router_) external onlyOwner {
        ROUTER_ADDRESS = router_;
        router = ThemisRouter(router_);
    }

    function handleWithTokens(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _data,
        address _token,
        uint256 _amount
    ) external override {
        emit ReceivedToken(_origin, _sender, string(_data), _token, _amount);
    }

    function getController(uint32 _domain) public view returns (address) {
        return controllers[_domain];
    }

    function checkLiquidityReceipt(uint32 _receipt) external pure returns (bool) {
        // TODO: check liquidity receipt
        return _receipt == 0;
    }

    /*//////////////////////////////////////////////////////////////
                            CORE AUCTION LOGIC
    //////////////////////////////////////////////////////////////*/

    function initialize(
        uint64 bidPeriod_,
        uint64 revealPeriod_,
        uint128 reservePrice_
    ) external onlyOwner {
        if (endOfBiddingPeriod != 0) revert AlreadyInitialized();

        endOfBiddingPeriod = uint64(block.timestamp) + bidPeriod_;
        endOfRevealPeriod =
            uint64(block.timestamp) + bidPeriod_ + revealPeriod_;
        reservePrice = reservePrice_;

        highestBids.initialize(uint32(MAX_SUPPLY + 1));

        emit AuctionInitialized(
            address(this),
            msg.sender,
            uint64(block.timestamp),
            endOfBiddingPeriod,
            endOfRevealPeriod,
            reservePrice
        );
    }

    uint128 someAmount;

    function testRouter() public returns (uint128) {
        someAmount = 56;
        return someAmount;
    }

    function checkBid(bytes32 bidder, uint128 bidAmount) external returns (bool) {
        // TODO: access control
        _bidder.init(bidder);
        // TODO: check endOfRevealPeriod
        // if (block.timestamp < endOfBiddingPeriod) revert NotInRevealPeriod();
        if (bidAmount < reservePrice) revert BidLowerThanReserve();

        (uint32 index, uint32 discarded) = highestBids.insert({
            domain: _bidder.getDomain(),
            bidderAddress: _bidder.getAddress(),
            bidAmount: bidAmount,
            bidTimestamp: uint64(block.timestamp)
        });

        emit BidRevealed(
            discarded,
            index,
            _bidder.getDomain(),
            _bidder.getAddress(),
            bidAmount,
            uint64(block.timestamp)
        );

        return index != 0;
    }

    // TODO: later
    function lateRevealBid() external {}

    function endAuction() external {
        if (block.timestamp < endOfRevealPeriod) revert AuctionNotOver();

        Bids.Node[] memory bids = highestBids.getAllBids();


        if (bids.length == 0) {
            emit AuctionEnded(block.timestamp);
            return;
        }

        if (bids.length == 1) {
            Bids.Node[] memory temp = new Bids.Node[](2);
            for (uint i=0;i<2;i++) {
                temp[i] = bids[0];
            }

            bids = temp;
        }

        for (uint i = 0; i < bids.length - 1; i++) {
            // accountRouter call -> check for liquidity
            uint32 destDomain = bids[i].domain;

            // TODO: fix this
            router.dispatchWithCallback(
                destDomain,
                getController(destDomain),
                abi.encodeCall(
                    ThemisController.deployVaultOnReveal,
                    (bids[i].bidderAddress, bids[i+1].bidAmount , bytes32(i)) // TODO: fix this
                ),
                abi.encodePacked(this.checkLiquidityReceipt.selector)
            );

            _reserve(bids[i].bidderAddress, i);

            emit BidShortlisted(
                uint32(i),
                bids[i].domain,
                bids[i].bidderAddress,
                bids[i].bidAmount
            );
        }

        emit AuctionEnded(block.timestamp);
    }

    function _reserve(address bidder_, uint256 id_) internal {
        reserved[id_] = bidder_;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(uint256 id) external {
        _mint(msg.sender, id);
    }

    function _mint(address to, uint256 id) internal override {
        // check if transfer was succefful
        if (id >= MAX_SUPPLY) revert InvalidTokenId();
        if (reserved[id] != to) revert NotReserved();
        super._mint(to, id);
    }

    function getHighestBids() external view returns (Bids.Node[] memory) {
        return highestBids.getAllBids();
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(BASE_ASSET_URI, id));
    }

    /*//////////////////////////////////////////////////////////////
                ONLY FOR TESTING, REMOVE IN PRODUCTION
    //////////////////////////////////////////////////////////////*/

    function endBidPeriod() external onlyOwner {
        endOfBiddingPeriod = uint64(block.timestamp);

        emit RevealStarted(endOfBiddingPeriod);
    }

    function endRevealPeriod() external onlyOwner {
        endOfRevealPeriod = uint64(block.timestamp);

        emit RevealEnded(endOfRevealPeriod);
    }


}
