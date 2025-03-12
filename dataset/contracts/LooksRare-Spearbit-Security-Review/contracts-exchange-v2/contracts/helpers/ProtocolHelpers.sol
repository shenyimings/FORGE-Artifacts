// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// Other dependencies
import {LooksRareProtocol} from "../LooksRareProtocol.sol";

/**
 * @title ProtocolHelpers
 * @notice This contract contains helper view functions for order creation.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract ProtocolHelpers {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleTree;

    // Encoding prefix for EIP-712 signatures
    string internal constant _ENCODING_PREFIX = "\x19\x01";

    // LooksRareProtocol
    LooksRareProtocol public looksRareProtocol;

    /**
     * @notice Constructor
     * @param _looksRareProtocol LooksRare protocol address
     */
    constructor(address _looksRareProtocol) {
        looksRareProtocol = LooksRareProtocol(_looksRareProtocol);
    }

    /**
     * @notice Compute digest for maker ask struct
     * @param makerAsk Maker ask struct
     * @return digest Digest
     */
    function computeDigestMakerAsk(OrderStructs.MakerAsk memory makerAsk) public view returns (bytes32 digest) {
        bytes32 domainSeparator = looksRareProtocol.domainSeparator();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, makerAsk.hash()));
    }

    /**
     * @notice Compute digest for maker bid struct
     * @param makerBid Maker bid struct
     * @return digest Digest
     */
    function computeDigestMakerBid(OrderStructs.MakerBid memory makerBid) public view returns (bytes32 digest) {
        bytes32 domainSeparator = looksRareProtocol.domainSeparator();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, makerBid.hash()));
    }

    /**
     * @notice Compute digest for merkle tree struct
     * @param merkleTree Merkle tree struct
     * @return digest Digest
     */
    function computeDigestMerkleTree(OrderStructs.MerkleTree memory merkleTree) public view returns (bytes32 digest) {
        bytes32 domainSeparator = looksRareProtocol.domainSeparator();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, merkleTree.hash()));
    }

    /**
     * @notice Verify maker ask order signature
     * @param makerAsk Maker ask struct
     * @param makerSignature Maker signature
     * @param signer Signer address
     * @dev It returns true only if the SignatureChecker does not revert before.
     */
    function verifyMakerAskOrder(
        OrderStructs.MakerAsk memory makerAsk,
        bytes calldata makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMakerAsk(makerAsk);
        SignatureChecker.verify(digest, signer, makerSignature);
        return true;
    }

    /**
     * @notice Verify maker bid order signature
     * @param makerBid Maker bid struct
     * @param makerSignature Maker signature
     * @param signer Signer address
     * @dev It returns true only if the SignatureChecker does not revert before.
     */
    function verifyMakerBidOrder(
        OrderStructs.MakerBid memory makerBid,
        bytes calldata makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMakerBid(makerBid);
        SignatureChecker.verify(digest, signer, makerSignature);
        return true;
    }

    /**
     * @notice Verify merkle tree signature
     * @param merkleTree Merkle tree struct
     * @param makerSignature Maker signature
     * @param signer Signer address
     * @dev It returns true only if the SignatureChecker does not revert before.
     */
    function verifyMerkleTree(
        OrderStructs.MerkleTree memory merkleTree,
        bytes calldata makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMerkleTree(merkleTree);
        SignatureChecker.verify(digest, signer, makerSignature);
        return true;
    }
}
