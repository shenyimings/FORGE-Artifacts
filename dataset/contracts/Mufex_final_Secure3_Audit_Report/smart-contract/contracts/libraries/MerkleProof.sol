// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./MiMC.sol";

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(uint256[] memory proof, uint256 root, uint256 leaf) internal pure returns (bool) {
        uint256 computedHash = leaf;
        uint256[] memory msgs = new uint256[](2);
        for (uint256 i = 0; i < proof.length; i++) {
            uint256 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                // computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
                msgs[0] = computedHash;
                msgs[1] = proofElement;
            } else {
                // Hash(current element of the proof + current computed hash)
                // computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
                msgs[0] = proofElement;
                msgs[1] = computedHash;
            }
            computedHash = MiMC.Hash(msgs);
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}
