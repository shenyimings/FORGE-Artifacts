// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title OrderStructs
 * @notice This library contains all order struct types for the LooksRare protocol (v2).
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
library OrderStructs {
    /**
     * @notice This is the constant used to compute the maker ask order hash.
     * @dev keccak256("MakerAsk(uint256 askNonce,uint256 subsetNonce,uint256 strategyId,uint256 assetType,uint256 orderNonce,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 minPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)")
     */
    bytes32 internal constant _MAKER_ASK_HASH = 0x88210d05352c99907588dddb658b9abce78f141d1415d7be787f6120b718fe02;

    /**
     * @notice This is the constant used to compute the maker bid order hash.
     * @dev keccak256("MakerBid(uint256 bidNonce,uint256 subsetNonce,uint256 strategyId,uint256 assetType,uint256 orderNonce,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 maxPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)")
     */
    bytes32 internal constant _MAKER_BID_HASH = 0xc69763700afbfcdc70a0b138ea120a08fc78dfc5532f1e7232fa8d8cfb26f96a;

    /**
     * @notice This is the constant used to compute the merkle root order hash (proof is not included in the hashing function).
     * @dev keccak256("MerkleTree(bytes32 root)")
     */
    bytes32 internal constant _MERKLE_TREE_HASH = 0x4339702fd09d392db18a2a980b04a717d48085f206207a9fe4472d7ba0ccbf0b;

    /**
     * 1. Maker structs
     */

    /**
     * @notice MakerAsk is the struct for a maker ask order. It contains one or multiple NFTs listed in a single order.
     * @param askNonce Global user order nonce for maker ask orders
     * @param subsetNonce Subset nonce (shared across bid/ask maker orders)
     * @param strategyId Strategy id
     * @param assetType Asset type (e.g. 0 = ERC721, 1 = ERC1155)
     * @param orderNonce Order nonce (it can be shared across bid/ask maker orders)
     * @param collection Collection address
     * @param currency Currency address (@dev address(0) = ETH)
     * @param signer Signer address
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @param minPrice Minimum price for execution
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order (e.g. it can contain start price for Dutch Auction)
     */
    struct MakerAsk {
        uint256 askNonce;
        uint256 subsetNonce;
        uint256 strategyId;
        uint256 assetType;
        uint256 orderNonce;
        address collection;
        address currency;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * @notice MakerBid is the struct for maker bid order. It represents offers made with fungible tokens.
     * @param bidNonce Global user order nonce for maker bid orders
     * @param subsetNonce Subset nonce (shared across bid/ask maker orders)
     * @param strategyId Strategy id
     * @param assetType Asset type (e.g. 0 = ERC721, 1 = ERC1155)
     * @param orderNonce Order nonce (it can be shared across bid/ask maker orders)
     * @param collection Collection address
     * @param currency Currency address (@dev ETH is not valid as a maker bid currency)
     * @param signer Signer address
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @param maxPrice Maximum price for execution
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order (e.g. it can contain a merkle root for specific strategies)
     */
    struct MakerBid {
        uint256 bidNonce;
        uint256 subsetNonce;
        uint256 strategyId;
        uint256 assetType;
        uint256 orderNonce;
        address collection;
        address currency;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 maxPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * 2. Taker structs
     */

    /**
     * @notice TakerAsk is the struct for a taker bid order. It contains the parameters required for a direct purchase.
     * @dev TakerAsk structs are matched against MakerBid structs at the protocol level.
     * @param recipient Recipient address (to receive non fungible tokens)
     * @param minPrice Minimum price for execution
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order
     */
    struct TakerAsk {
        address recipient;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * @notice TakerBid is the struct for a taker bid order. It contains the parameters required for a direct purchase.
     * @dev TakerBid structs are matched against MakerAsk structs at the protocol level.
     * @param recipient Recipient address (to receive non fungible tokens)
     * @param maxPrice Maximum price for execution
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order
     */
    struct TakerBid {
        address recipient;
        uint256 maxPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * 3. Merkle tree
     */

    /**
     * @notice MerkleTree is the struct for a merkle tree of order hashes.
     * @dev A Merkle tree can be computed with order hashes. It can contain order hashes from both maker bid and maker ask structs.
     * @param root Merkle root
     * @param proof Array containing the merkle proof
     */
    struct MerkleTree {
        bytes32 root;
        bytes32[] proof;
    }

    /**
     * 4. Hash functions
     */

    /**
     * @notice This function is used to compute the order hash for a maker ask struct.
     * @param makerAsk Maker ask order struct
     * @return makerAskHash Hash of the maker ask struct
     */
    function hash(MakerAsk memory makerAsk) internal pure returns (bytes32 makerAskHash) {
        // Encoding is done into two parts to avoid stack too deep issues
        return
            keccak256(
                bytes.concat(
                    abi.encode(
                        _MAKER_ASK_HASH,
                        makerAsk.askNonce,
                        makerAsk.subsetNonce,
                        makerAsk.strategyId,
                        makerAsk.assetType,
                        makerAsk.orderNonce,
                        makerAsk.collection,
                        makerAsk.currency
                    ),
                    abi.encode(
                        makerAsk.signer,
                        makerAsk.startTime,
                        makerAsk.endTime,
                        makerAsk.minPrice,
                        keccak256(abi.encodePacked(makerAsk.itemIds)),
                        keccak256(abi.encodePacked(makerAsk.amounts)),
                        keccak256(makerAsk.additionalParameters)
                    )
                )
            );
    }

    /**
     * @notice This function is used to compute the order hash for a maker bid struct.
     * @param makerBid Maker bid order struct
     * @return makerBidHash Hash of the maker bid struct
     */
    function hash(MakerBid memory makerBid) internal pure returns (bytes32 makerBidHash) {
        return (
            keccak256(
                bytes.concat(
                    abi.encode(
                        _MAKER_BID_HASH,
                        makerBid.bidNonce,
                        makerBid.subsetNonce,
                        makerBid.strategyId,
                        makerBid.assetType,
                        makerBid.orderNonce,
                        makerBid.collection,
                        makerBid.currency
                    ),
                    abi.encode(
                        makerBid.signer,
                        makerBid.startTime,
                        makerBid.endTime,
                        makerBid.maxPrice,
                        keccak256(abi.encodePacked(makerBid.itemIds)),
                        keccak256(abi.encodePacked(makerBid.amounts)),
                        keccak256(makerBid.additionalParameters)
                    )
                )
            )
        );
    }

    /**
     * @notice This function is used to compute the hash for a merkle tree struct.
     * @param merkleTree Merkle tree struct
     * @return merkleTreeHash Hash of the merkle tree struct
     */
    function hash(MerkleTree memory merkleTree) internal pure returns (bytes32 merkleTreeHash) {
        merkleTreeHash = (keccak256(abi.encode(_MERKLE_TREE_HASH, merkleTree.root)));
    }
}
