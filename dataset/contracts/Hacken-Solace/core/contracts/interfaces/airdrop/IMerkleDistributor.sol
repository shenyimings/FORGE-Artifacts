// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleDistributor {
    // @notice This event is triggered whenever a call to #claim succeeds.
    event Claimed(address indexed user, uint256 amount);

    // @notice This event is triggered whenever a call to #governorRecoverAirdropTokens succeeds.
    event GovernorRecoverAirdropTokens(uint256 amount);

    // @notice Returns the address of the token distributed by this contract.
    function token() external view returns (address);

    // @notice Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);
    /**
     * @notice Returns true if address has claimed, false if not.
     * @param user Address of user to check.
     */    
    function hasClaimed(address user) external view returns (bool);

    /**
     * @notice Airdrop claim functions.
     * @notice Recommended to use offchain script to compute merkleProof from merkle tree, which has also been generated offchain.
     * @param user Address of airdrop claimer.
     * @param amount Amount of airdrop to claim. Note - Has to match value in merkle tree used to generate merkle root.
     * @param merkleProof Merkle proof or Merkle path, to calculate merkle root given this node - (user, amount). Note - Recommend using offchain script to compute.
     */
    function claim(address user, uint256 amount, bytes32[] calldata merkleProof) external;

    /**
     * @notice Governance-only function to recover airdrop tokens from this smart contract,
     * In the case that a significant amount of airdrop tokens are not claimed
     */
    function governorRecoverAirdropTokens() external;
}