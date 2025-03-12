// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IMerkleAirdrop } from "../interfaces/IMerkleAirdrop.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "./MerkleProof.sol";

contract MerkleAirdrop is IMerkleAirdrop, Ownable {
  using SafeERC20 for IERC20;

  error MerkleAirdrop_Initialized();
  error MerkleAirdrop_AlreadyClaimed();
  error MerkleAirdrop_InvalidProof();
  error MerkleAirdrop_NotExpired();

  address public override token;
  bytes32 public override merkleRoot;
  bool public initialized;
  uint256 public expireTimestamp;

  // This is a packed array of booleans.
  mapping(uint256 => uint256) public claimedBitMap;

  function init(
    address owner_,
    address token_,
    bytes32 merkleRoot_,
    uint256 expireTimestamp_
  ) external {
    if (initialized) revert MerkleAirdrop_Initialized();
    initialized = true;

    token = token_;
    merkleRoot = merkleRoot_;
    expireTimestamp = expireTimestamp_;

    _transferOwnership(owner_);
  }

  function isClaimed(uint256 index) public view override returns (bool) {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    uint256 claimedWord = claimedBitMap[claimedWordIndex];
    uint256 mask = (1 << claimedBitIndex);
    return claimedWord & mask == mask;
  }

  function _setClaimed(uint256 index) private {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    claimedBitMap[claimedWordIndex] =
      claimedBitMap[claimedWordIndex] |
      (1 << claimedBitIndex);
  }

  function claim(
    uint256 index,
    address account,
    uint256 amount,
    bytes32[] calldata merkleProof
  ) external override {
    if (isClaimed(index)) revert MerkleAirdrop_AlreadyClaimed();

    // Verify the merkle proof.
    bytes32 node = keccak256(abi.encodePacked(index, account, amount));
    if (!MerkleProof.verify(merkleProof, merkleRoot, node))
      revert MerkleAirdrop_InvalidProof();

    // Mark it claimed and send the token.
    _setClaimed(index);
    IERC20(token).safeTransfer(account, amount);

    emit Claimed(index, account, amount);
  }

  function sweep(address token_, address target) external onlyOwner {
    require(
      block.timestamp >= expireTimestamp || token_ != token,
      "MerkleAirdrop: Not expired"
    );
    IERC20 tokenContract = IERC20(token_);
    uint256 balance = tokenContract.balanceOf(address(this));
    tokenContract.safeTransfer(target, balance);
  }
}
