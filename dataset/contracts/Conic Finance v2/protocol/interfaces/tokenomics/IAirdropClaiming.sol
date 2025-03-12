// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../libraries/MerkleProof.sol";

interface IAirdropClaiming {
    /// @notice emitted when a user claims his airdroped
    event Claimed(address indexed claimer, uint256 amount);

    /// @notice emitted when the merkle root is initialized
    event MerkleRootInitialized(bytes32 merkleRoot);

    /// @notice emitted at the end of the airdrop when the rest of the tokens is refunded
    event Refunded(uint256 amount);

    /// @notice initializes the merkle root of the airdrop
    function initializeMerkleRoot(bytes32 _merkleRoot) external;

    /// @return the refund address for non-claimed tokens
    function refundAddress() external view returns (address);

    /// @notice refunds the tokens that have not been claimed
    function refundNonClaimed() external;

    /// @notice returns the total amount of claimed tokens
    function claimed() external view returns (uint256);

    /// @return the total amount of tokens claimed by `_claimer`
    function claimedBy(address _claimer) external view returns (uint256);

    /// @return the merkle root
    function merkleRoot() external view returns (bytes32);

    /// @return the token being airdropped
    function token() external view returns (IERC20);

    /// @return the end date of the airdrop
    function endsAt() external view returns (uint256);

    /// @notice claims `amount` on behalf of `claimer`
    /// the proof is a merkle proof of the claim
    function claim(address claimer, uint256 amount, MerkleProof.Proof calldata proof) external;
}
