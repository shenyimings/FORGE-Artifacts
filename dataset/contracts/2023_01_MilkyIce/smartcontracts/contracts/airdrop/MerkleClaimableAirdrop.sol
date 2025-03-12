// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

error MerkleClaimableAirdrop__AlreadyClaimed();
error MerkleClaimableAirdrop__InvalidProof();

/**
 * @notice Allows claiming tokens if address is part of a merkle tree
 * @dev This contract is Ownable and Pausable because the team wants to have the ability to finish the airdrop
 * whenever they consider it appropriate for the community. The team also wants to have the ability to withdraw
 * the remaining unclaimed tokens from the contract after the airdrop is finished.
 */
contract MerkleClaimableAirdrop is Ownable, Pausable {
  using SafeERC20 for IERC20;

  /// @notice Emitted after a successful token claim
  /// @param to recipient of claim
  /// @param amount of tokens claimed
  event Claimed(address indexed to, uint256 amount);

  bytes32 public immutable merkleRoot;
  IERC20 public immutable token;
  IERC20 public immutable rewardToken;

  mapping(address => bool) public hasClaimed;

  constructor(IERC20 _token, IERC20 _rewardToken, bytes32 _merkleRoot) {
    token = _token;
    rewardToken = _rewardToken;
    merkleRoot = _merkleRoot;
  }

  /// @notice Allows claiming tokens if address is part of a merkle tree
  /// @param _to address of claimee
  /// @param _amount of tokens owed to claimee
  /// @param _rewardAmount amount of reward tokens owed to claimee
  /// @param _proof merkle proof to prove that the address and the amount are in tree
  function claim(
    address _to,
    uint256 _amount,
    uint256 _rewardAmount,
    bytes32[] calldata _proof
  ) external whenNotPaused {
    if (hasClaimed[_to]) revert MerkleClaimableAirdrop__AlreadyClaimed();

    // Verify merkle proof, or revert if not in tree
    bytes32 leaf = keccak256(abi.encodePacked(_to, _amount, _rewardAmount));
    bool isValidLeaf = MerkleProof.verify(_proof, merkleRoot, leaf);
    if (!isValidLeaf) revert MerkleClaimableAirdrop__InvalidProof();

    hasClaimed[_to] = true;

    token.safeTransfer(_to, _amount);
    rewardToken.safeTransfer(_to, _rewardAmount);

    emit Claimed(_to, _amount);
  }

  // ======== OWNER FUNCTIONS ========

  /// @notice Allows the team to withdraw unclaimed tokens after airdrop is finished
  function withdrawRemaining() external onlyOwner whenPaused {
    uint256 balance = token.balanceOf(address(this));
    token.safeTransfer(owner(), balance);
    uint256 rewardsBalance = rewardToken.balanceOf(address(this));
    rewardToken.safeTransfer(owner(), rewardsBalance);
  }

  /// @notice Is used by the team to finish the airdrop
  /// @dev due to lack of unpause function, the team can't resume the airdrop after it's finished
  function finishAirdrop() external onlyOwner {
    _pause();
  }
}
