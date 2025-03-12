// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// allows messages from L1 -> L2
interface IControlL2MerkleDistributor {
    /// @notice claim $KWENTA on L2 from an L1 address
    /// @dev destAccount will be the address used to create new escrow entry
    /// @dev the function caller (i.e. msg.sender) will be provided as a parameter
    /// to MerkleDistributor.claimToAddress() on L2. Only valid callers will
    /// be able to claim
    /// @param index: used for merkle tree managment and verification
    /// @param destAccount: address used for escrow entry
    /// @param amount: $KWENTA amount to be escrowed
    /// @param merkleProof: off-chain generated proof of merkle tree inclusion
    function claimToAddress(uint256 index, address destAccount, uint256 amount, bytes32[] calldata merkleProof) external;
}
