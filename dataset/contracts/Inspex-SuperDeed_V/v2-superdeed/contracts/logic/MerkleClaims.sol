// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/DataType.sol";

library MerkleClaims {

    function isClaimed(DataType.Group storage group, uint index) internal view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = group.deedClaimMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function setClaimed(DataType.Group storage group, uint index) internal {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        group.deedClaimMap[claimedWordIndex] = group.deedClaimMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(DataType.Group storage group, uint index, address account, uint256 amount, bytes32[] calldata merkleProof) internal  {
        _require(!isClaimed(group, index), "Already claimed.");
        _require( amount > 0 && verifyClaim(group, index, account, amount, merkleProof), "Invalid amount or proof");
        setClaimed(group, index);
    }

    function verifyClaim(DataType.Group storage group, uint index, address account, uint amount, bytes32[] calldata merkleProof) internal view returns (bool) {
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        return MerkleProof.verify(merkleProof, group.merkleRoot, node);
    }

    function _require(bool condition, string memory error) pure internal {
        require(condition, error);
    }
}
