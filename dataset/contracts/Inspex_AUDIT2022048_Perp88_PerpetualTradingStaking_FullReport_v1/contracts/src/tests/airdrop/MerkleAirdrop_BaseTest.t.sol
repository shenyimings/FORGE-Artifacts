// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseTest, console, MerkleAirdrop, MerkleAirdropFactory, MerkleAirdropGateway } from "../base/BaseTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract MerkleAirdrop_BaseTest is BaseTest {
  MerkleAirdrop internal merkleAirdropTemplate;
  MerkleAirdropFactory internal merkleAirdropFactory;
  MerkleAirdropGateway internal gateway;
  bytes32 internal merkleRoot =
    0xe8265d62c006291e55af5cc6cde08360d1362af700d61a06087c7ce21b2c31b8;
  bytes32 internal salt = keccak256("1");
  bytes32 internal ipfsHash = keccak256("1");

  function setUp() public virtual {
    merkleAirdropTemplate = deployMerkleAirdrop();
    merkleAirdropFactory = deployMerkleAirdropFactory();
    gateway = deployMerkleAirdropGateway();
  }
}
