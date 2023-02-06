// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

import {Bids} from "src/lib/Bids.sol";
import {LibBalanceProof} from "src/lib/LibBalanceProof.sol";
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
    address public collateralToken;

    /// @notice A mapping storing whether or not the bid for a `ThemisVault` was revealed.
    mapping(address => bool) public revealedVaults;
    /// @notice A mapping storing the amount of collateral allocated for the the actual bid
    mapping (address => uint128) public amountOwed;

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
    /// param proof The proof that the vault corresponding to this bid was
    ///        sufficiently collateralized before any bids were revealed. This
    ///        may be null if this is the first bid revealed for the auction.
    function revealBid(
        address bidder,
        bytes32 salt,
        uint32 justGreaterBidIndex,
        uint32 justLesserBidIndex,
        CollateralizationProof calldata /* proof */
    ) external {
        if (
            block.timestamp < endOfBiddingPeriod ||
            block.timestamp >  endOfRevealPeriod
        ) {
            unlockVault(bidder, salt);
            return;
        }

        address vault = getVaultAddress(address(this), collateralToken, bidder, salt);

        if (revealedVaults[vault]) {
            unlockVault(bidder, salt);
            return;
        }
        revealedVaults[vault] = true;

        // TODO: JUST FOR TESTING
        uint256 vaultBalance = ERC20(collateralToken).balanceOf(vault);

        if (vaultBalance < reservePrice) {
            unlockVault(bidder, salt);
            // revert BidLowerThanReserve();
            return;
        }

        Bids.Element memory bidToBeInserted = Bids.Element({
            bidder: bidder,
            salt: salt,
            amount: uint128(vaultBalance),
            blockNumber: uint64(block.timestamp),

            prevKey: justLesserBidIndex,
            nextKey: justGreaterBidIndex
        });

        (uint32 index, uint32 discarded) = highestBids.insert(bidToBeInserted);

        if (discarded != 0) {
            unlockVault(bidder, salt);
            Bids.Element memory discardedBid = highestBids.getBid(discarded);

            emit BidDiscarded(
                discardedBid.bidder,
                discardedBid.amount,
                discardedBid.blockNumber
            );
        }

        Bids.Element memory inserted = highestBids.getBid(index);
        emit BidRevealed(
            inserted.bidder,
            inserted.amount,
            inserted.blockNumber
        );
    }

    /// @notice Ends an active auction. Can only end an auction if the bid reveal
    ///         phase is over.
    function endAuction() external {
        if (block.timestamp < endOfRevealPeriod) revert AuctionNotOver();

        Bids.Element[] memory bids = highestBids.getAllBids();

        if (bids.length == 0) {
            emit AuctionEnded(block.timestamp);
            return;
        }

        if (bids.length == 1) {
            Bids.Element[] memory temp = new Bids.Element[](2);
            temp[0] = bids[0];
            temp[1] = bids[0];
            bids = temp;
        }

        for (uint i = 0; i < bids.length - 1; i++) {
            amountOwed[bids[i].bidder] = bids[i + 1].amount;
            unlockVault(bids[i].bidder, bids[i].salt);
            _mint(bids[i].bidder, i);
        }

        emit AuctionEnded(block.timestamp);
    }

    function bidAmounts(address vault) external view returns (uint128) {
        return amountOwed[vault];
    }

    function setCollateralToken(address collateralToken_) external onlyOwner {
        collateralToken = collateralToken_;
    }

    function unlockVault(address bidder, bytes32 salt) public {
        address vault = getVaultAddress(address(this), collateralToken, bidder, salt);
        if (vault.code.length == 0)
            new ThemisVault{salt: salt}(address(this), collateralToken, bidder);
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
    /// @param collateralToken_ The address of the ERC20 contract for the collateral token.
    /// @param bidder The address of the bidder.
    /// @param salt The random input used to obfuscate the commitment.
    /// @return vault The address of the `ThemisVault`.
    function getVaultAddress(
        address tokenContract,
        address collateralToken_,
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
                    collateralToken_,
                    bidder
                )
            ))
        )))));
    }

    /// @dev Gets the balance of the given account at a past block by
    ///      traversing the given Merkle proof for the state trie. Wraps
    ///      LibBalanceProof.getProvenAccountBalance so that this function
    ///      can be overridden for testing.
    /// @param proof A Merkle proof for the given account's balance in
    ///        the state trie of a past block.
    /// @param blockHeaderRLP The RLP-encoded block header for the past
    ///        block for which the balance is being queried.
    /// @param blockHash The expected blockhash. Should be equal to the
    ///        Keccak256 hash of `blockHeaderRLP`.
    /// @param account The account whose past balance is being queried.
    /// @return accountBalance The proven past balance of the account.
    function _getProvenAccountBalance(
        bytes[] memory proof,
        bytes memory blockHeaderRLP,
        bytes32 blockHash,
        address account
    )
        internal
        virtual
        view
        returns (uint256 accountBalance)
    {
        return LibBalanceProof.getProvenAccountBalance(
            proof,
            blockHeaderRLP,
            blockHash,
            account
        );
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
