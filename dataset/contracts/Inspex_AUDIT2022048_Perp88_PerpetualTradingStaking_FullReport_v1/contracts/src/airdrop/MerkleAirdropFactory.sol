// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { CloneFactory } from "./CloneFactory.sol";
import { MerkleAirdrop } from "./MerkleAirdrop.sol";

contract MerkleAirdropFactory is CloneFactory {
  event CreateMerkleAirdrop(address merkleAirdrop, bytes32 ipfsHash);

  function createMerkleAirdrop(
    address template,
    address token,
    bytes32 merkleRoot,
    uint256 expireTimestamp,
    bytes32 salt,
    bytes32 ipfsHash
  ) external returns (MerkleAirdrop drop) {
    drop = MerkleAirdrop(createClone(template, salt));
    drop.init(msg.sender, token, merkleRoot, expireTimestamp);
    emit CreateMerkleAirdrop(address(drop), ipfsHash);
  }

  function computeMerkleAirdropAddress(address template, bytes32 salt)
    external
    view
    returns (address)
  {
    return computeCloneAddress(template, salt);
  }

  function isMerkleAirdrop(address template, address query)
    external
    view
    returns (bool)
  {
    return isClone(template, query);
  }
}
