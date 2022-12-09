// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Auction} from "src/lib/Auction.sol";
import {LibBalanceProof} from "src/lib/LibBalanceProof.sol";

import {IThemis} from "src/IThemis.sol";
import {ThemisVault} from "src/ThemisVault.sol";

contract ThemisController is IThemis {


    bytes32 auction;
    mapping(address => bool) revealedVault;

    uint32 domain;
    uint96 revealStartBlock;
    bytes32 storedBlockHash;

    bool isCollateralized;

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


    constructor() {
    }

    function connectAuction(uint32 domain_, address contract_) external {
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

    function revealBid(
        address bidder_,
        uint128 bidAmount_,
        bytes32 salt_,
        CollateralizationProof calldata proof_
    ) external {
        address vault = getVaultAddress(
            auction,
            bidder_,
            bidAmount_,
            salt_
        );

        if (revealedVault[vault]) revert BidAlreadyRevealed();
        revealedVault[vault] = true;

        uint256 vaultBalance = _getProvenAccountBalance(
            proof_.accountMerkleProof,
            proof_.blockHeaderRLP,
            storedBlockHash,
            vault
        );
        if (vaultBalance < bidAmount_) {
            new ThemisVault{salt: salt_}(
                auction,
                bidder_,
                bidAmount_
            );
            isCollateralized = false;
        }

        if (isCollateralized) {
            // _dispatch();
        }

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

    /// @dev Gets the balance of the given account at a past block by
    ///      traversing the given Merkle proof for the state trie. Wraps
    ///      LibBalanceProof.getProvenAccountBalance so that this function
    ///      can be overriden for testing.
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

    function max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }
}
