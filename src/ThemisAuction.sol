// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// import "forge-std/console.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

import {Bids} from "src/lib/Bids.sol";
import {IThemis} from "src/IThemis.sol";
import {ThemisVault} from "src/ThemisVault.sol";

contract ThemisAuction is IThemis, ERC721 {
    using Bids for Bids.List;

    string public BASE_ASSET_URI;

    address public collectionOwner;

    uint256 public immutable MAX_SUPPLY;

    Bids.List public highestBids;

    /// @dev A Merkle proof and block header, in conjunction with the
    ///      stored `collateralizationDeadlineBlockHash` for an auction,
    ///      is used to prove that a bidder's `SneakyVault` was sufficiently
    ///      collateralized by the time the first bid was revealed.
    /// @param accountMerkleProof The Merkle proof of a particular account's
    ///        state, as returned by the `eth_getProof` RPC method.
    /// @param blockHeaderRLP The RLP-encoded header of the block
    ///        for which the account balance is being proven.
    struct CollateralizationProof {
        bytes[] accountMerkleProof;
        bytes blockHeaderRLP;
    }

    /// @notice end of bidding period time stamp for the auction
    uint64 public endOfBiddingPeriod;
    /// @notice end of reveal period time stamp for the auction
    uint64 public endOfRevealPeriod;
    /// @notice reserve price for the mint
    uint128 public reservePrice;
    /// @notice collateral token specified for bids
    address collateralToken;

    /// @notice A mapping storing whether or not the bid for a `ThemisVault` was revealed.
    mapping(address => bool) public revealedVaults;

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
        endOfRevealPeriod = uint64(block.timestamp) + bidPeriod_ + revealPeriod_;
        reservePrice = reservePrice_;

        highestBids.init(uint32(MAX_SUPPLY + 1));

        emit AuctionInitialized(
            address(this),
            msg.sender,
            uint64(block.timestamp),
            endOfBiddingPeriod,
            endOfRevealPeriod,
            reservePrice
        );
    }

    /// @notice Reveals the value of a bid that was previously committed to.
    /// @param bidder The address of the bidder who committed to this bid.
    /// @param salt The random input used to obfuscate the commitment.
    /// @param justLesserBidIndex The index of the bid just smaller in the DLL
    ///        of bids. This is used to efficiently find the element in the DLL
    /// @param justGreaterBidIndex The index of the bid just greater in the DLL
    ///        of bids. This is used to efficiently find the element in the DLL
    /// @param proof The proof that the vault corresponding to this bid was
    ///        sufficiently collateralized before any bids were revealed. This
    ///        may be null if this is the first bid revealed for the auction.
    function revealBid(
        address bidder,
        bytes32 salt,
        uint32 justLesserBidIndex,
        uint32 justGreaterBidIndex,
        CollateralizationProof calldata proof
    ) external {
        if (
            block.timestamp < endOfBiddingPeriod ||
            block.timestamp >  endOfRevealPeriod
        ) revert NotInRevealPeriod();

        address vault = getVaultAddress(address(this), collateralToken, bidder, salt);

        if (revealedVaults[vault]) revert BidAlreadyRevealed();
        revealedVaults[vault] = true;

        // TODO: JUST FOR TESTING
        uint256 vaultBalance = ERC20(collateralToken).balanceOf(vault);

        if (vaultBalance < reservePrice) revert BidLowerThanReserve();

        Bids.Element memory bidToBeInserted = Bids.Element({
            bidder: bidder,
            amount: uint128(vaultBalance),
            blockNumber: uint64(block.timestamp),

            prevKey: justLesserBidIndex,
            nextKey: justGreaterBidIndex
        });

        (uint32 index, uint32 discarded) = highestBids.insert(bidToBeInserted);

        emit BidRevealed(
            discarded,
            index,
            0,
            address(this),
            uint128(vaultBalance),
            uint64(block.timestamp)
        );
    }


    function endAuction() external {
        if (block.timestamp < endOfRevealPeriod) revert AuctionNotOver();

        Bids.Element[] memory bids = highestBids.getAllBids();

        if (bids.length == 0) {
            emit AuctionEnded(block.timestamp);
            return;
        }

        if (bids.length == 1) {
            Bids.Element[] memory temp = new Bids.Element[](2);
            for (uint i=0;i<2;i++) {
                temp[i] = bids[0];
            }

            bids = temp;
        }

        for (uint i = 0; i < bids.length - 1; i++) {
            new ThemisVault{salt: bytes32(i)}(address(this), collateralToken, bids[i].bidder);

            _mint(bids[i].bidder, i);
        }

        emit AuctionEnded(block.timestamp);
    }

    function bidAmounts(address bidder) external view returns (uint128) {
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(uint256 id) external {
        _mint(msg.sender, id);
    }

    function _mint(address to, uint256 id) internal override {
        // TODO: disable direct minting
        if (id >= MAX_SUPPLY) revert InvalidTokenId();
        super._mint(to, id);
    }

    function getHighestBids() external view returns (Bids.Element[] memory) {
        return highestBids.getAllBids();
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(BASE_ASSET_URI, id));
    }

    /// @notice Computes the `CREATE2` address of the `ThemisVault` with the given
    ///         parameters. Note that the vault contract may not be deployed yet.
    /// @param tokenContract The address of the ERC721 contract for the asset auctioned.
    /// @param collateralToken The address of the ERC20 contract for the collateral token.
    /// @param bidder The address of the bidder.
    /// @param salt The random input used to obfuscate the commitment.
    /// @return vault The address of the `ThemisVault`.
    function getVaultAddress(
        address tokenContract,
        address collateralToken,
        address bidder,
        bytes32 salt
    )
        public
        view
        returns (address vault)
    {
        // Compute `CREATE2` address of vault
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(abi.encodePacked(
                type(ThemisVault).creationCode,
                abi.encode(
                    tokenContract,
                    collateralToken,
                    bidder
                )
            ))
        )))));
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
