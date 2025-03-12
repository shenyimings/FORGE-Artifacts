// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { MerkleAirdrop_BaseTest, MerkleAirdrop } from "./MerkleAirdrop_BaseTest.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MerkleAirdrop_CreateMerkleAirdrop is MerkleAirdrop_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_CreateMerkleAirdrop() external {
    MerkleAirdrop newMerkleAirdrop = merkleAirdropFactory.createMerkleAirdrop(
      address(merkleAirdropTemplate),
      address(usdc),
      merkleRoot,
      block.timestamp + 7 days,
      salt,
      ipfsHash
    );

    address computedMerkleAirdropAddress = merkleAirdropFactory
      .computeMerkleAirdropAddress(address(merkleAirdropTemplate), salt);
    assertEq(address(newMerkleAirdrop), computedMerkleAirdropAddress);

    assertTrue(
      merkleAirdropFactory.isMerkleAirdrop(
        address(merkleAirdropTemplate),
        address(newMerkleAirdrop)
      )
    );
  }
}
