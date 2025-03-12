// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title IceAirdrop
/// @notice This contract is used for the Ice ERC20 token airdrop, not the NFT airdrop
contract IceAirdrop is Ownable {
  using SafeERC20 for ERC20;

  constructor(address _iceToken) {
    ice = ERC20(_iceToken);
    iceClaimState = true;
  }

  ERC20 public ice;
  mapping(uint256 => bytes32) public airdropMerkleRoot;
  mapping(uint256 => mapping(address => bool)) public airdropClaimed;

  bool public iceClaimState;
  uint256 public round;

  event ClaimReward(address indexed user, uint256 amount, uint256 round);

  function setIceToken(address _ice) external onlyOwner {
    ice = ERC20(_ice);
  }

  function setIceClaimState(bool _state) external onlyOwner {
    iceClaimState = _state;
  }

  function setAirdropMerkleRoot(uint256 _round, bytes32 _airdropMerkleRoot) external onlyOwner {
    airdropMerkleRoot[_round] = _airdropMerkleRoot;
    round = _round;
  }

  function claimAirdrop(uint256 _round, uint256 amount, bytes32[] calldata proof) external {
    require(iceClaimState, "Airdrop is not active");
    require(_round == round, "Invalid round");
    require(airdropMerkleRoot[_round] != bytes32(0), "Merkle root not set");
    require(!airdropClaimed[_round][msg.sender], "Already claimed");
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
    require(MerkleProof.verifyCalldata(proof, airdropMerkleRoot[_round], leaf), "Invalid merkle proof");
    airdropClaimed[_round][msg.sender] = true;
    ice.safeTransfer(msg.sender, amount);
    emit ClaimReward(msg.sender, amount, _round);
  }

  function withdrawExpireUnclaimedTokens() external onlyOwner {
    ice.safeTransfer(msg.sender, ice.balanceOf(address(this)));
  }

  function withdrawErc20(address _token) external onlyOwner {
    ERC20(_token).safeTransfer(msg.sender, ERC20(_token).balanceOf(address(this)));
  }

  function withdrawEth() external onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }
}
