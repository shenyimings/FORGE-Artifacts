// SPDX-License-Identifier: MIT

// File contracts/MerkleWhitelisting.sol
pragma solidity 0.7.6;

import "@openzeppelin/contracts/cryptography/MerkleProof.sol";

contract MerkleWhitelisting {
    // Merkle root which consists of whitelisted users.
    bytes32 public root;

    /**
     * @notice Merkle verification is done.
     *
     * @param _leaf Leaf in the merkle tree.
     * @param _proof Merkle Proof which includes `_leaf`.
     */
    function _verify(bytes32 _leaf, bytes32[] memory _proof)
        internal
        view
        returns (bool)
    {
        return MerkleProof.verify(_proof, root, _leaf);
    }

    /**
     * @notice Does hashing of the account.
     *
     * @param _account Address of user.
     */
    function _calculateLeaf(address _account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account));
    }
}
