// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/
pragma solidity 0.8.17;

import { IMerkleAirdrop } from "../interfaces/IMerkleAirdrop.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "./MerkleProof.sol";

contract MerkleAirdrop is Ownable {
  using SafeERC20 for IERC20;

  error MerkleAirdrop_Initialized();
  error MerkleAirdrop_AlreadyClaimed();
  error MerkleAirdrop_InvalidProof();
  error MerkleAirdrop_CannotInitFutureWeek();
  error MerkleAirdrop_Unauthorized();

  // This event is triggered whenever a call to #claim succeeds.
  event Claimed(
    uint256 weekTimestamp,
    uint256 index,
    address account,
    uint256 amount
  );
  event SetFeeder(address oldFeeder, address newFeeder);
  event Init(uint256 weekTimestamp, bytes32 merkleRoot);

  address public token;
  address public feeder;
  mapping(uint256 => bytes32) public merkleRoot; // merkleRoot mapping by week timestamp
  mapping(uint256 => bool) public initialized;

  // This is a packed array of booleans.
  mapping(uint256 => mapping(uint256 => uint256)) public claimedBitMap; // claimedBitMap mapping by week timestamp

  constructor(address token_, address feeder_) {
    token = token_;
    feeder = feeder_;
  }

  modifier onlyFeederOrOwner() {
    if (msg.sender != feeder && msg.sender != owner())
      revert MerkleAirdrop_Unauthorized();
    _;
  }

  function setFeeder(address newFeeder) external onlyOwner {
    emit SetFeeder(feeder, newFeeder);
    feeder = newFeeder;
  }

  function init(uint256 weekTimestamp, bytes32 merkleRoot_)
    external
    onlyFeederOrOwner
  {
    uint256 currentWeekTimestamp = block.timestamp / (60 * 60 * 24 * 7);
    if (currentWeekTimestamp <= weekTimestamp)
      revert MerkleAirdrop_CannotInitFutureWeek();
    if (initialized[weekTimestamp]) revert MerkleAirdrop_Initialized();

    merkleRoot[weekTimestamp] = merkleRoot_;
    initialized[weekTimestamp] = true;

    emit Init(weekTimestamp, merkleRoot_);
  }

  function isClaimed(uint256 weekTimestamp, uint256 index)
    public
    view
    returns (bool)
  {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    uint256 claimedWord = claimedBitMap[weekTimestamp][claimedWordIndex];
    uint256 mask = (1 << claimedBitIndex);
    return claimedWord & mask == mask;
  }

  function _setClaimed(uint256 weekTimestamp, uint256 index) private {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    claimedBitMap[weekTimestamp][claimedWordIndex] =
      claimedBitMap[weekTimestamp][claimedWordIndex] |
      (1 << claimedBitIndex);
  }

  function claim(
    uint256 weekTimestamp,
    uint256 index,
    address account,
    uint256 amount,
    bytes32[] calldata merkleProof
  ) external {
    _claim(weekTimestamp, index, account, amount, merkleProof);
  }

  function bulkClaim(
    uint256[] calldata weekTimestamps,
    uint256[] calldata indices,
    address[] calldata accounts,
    uint256[] calldata amounts,
    bytes32[][] calldata merkleProof
  ) external {
    for (uint256 i = 0; i < weekTimestamps.length; ) {
      _claim(
        weekTimestamps[i],
        indices[i],
        accounts[i],
        amounts[i],
        merkleProof[i]
      );
      unchecked {
        i++;
      }
    }
  }

  function _claim(
    uint256 weekTimestamp,
    uint256 index,
    address account,
    uint256 amount,
    bytes32[] calldata merkleProof
  ) internal {
    if (isClaimed(weekTimestamp, index)) revert MerkleAirdrop_AlreadyClaimed();

    // Verify the merkle proof.
    bytes32 node = keccak256(abi.encodePacked(index, account, amount));
    if (!MerkleProof.verify(merkleProof, merkleRoot[weekTimestamp], node))
      revert MerkleAirdrop_InvalidProof();

    // Mark it claimed and send the token.
    _setClaimed(weekTimestamp, index);
    IERC20(token).safeTransfer(account, amount);

    emit Claimed(weekTimestamp, index, account, amount);
  }

  function emergencyWithdraw(address receiver) external onlyOwner {
    IERC20 tokenContract = IERC20(token);
    uint256 balance = tokenContract.balanceOf(address(this));
    tokenContract.safeTransfer(receiver, balance);
  }
}
