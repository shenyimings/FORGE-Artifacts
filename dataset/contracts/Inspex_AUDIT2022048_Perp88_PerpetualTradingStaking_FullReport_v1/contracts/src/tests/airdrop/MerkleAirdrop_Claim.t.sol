// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { MerkleAirdrop_BaseTest, MerkleAirdrop } from "./MerkleAirdrop_BaseTest.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MerkleAirdrop_Claim is MerkleAirdrop_BaseTest {
  MerkleAirdrop internal merkleAirdrop;

  function setUp() public override {
    super.setUp();
    merkleAirdrop = merkleAirdropFactory.createMerkleAirdrop(
      address(merkleAirdropTemplate),
      address(usdc),
      merkleRoot,
      block.timestamp + 7 days,
      salt,
      ipfsHash
    );
    usdc.mint(address(this), 4497.234393 * 10**6);
    usdc.transfer(address(merkleAirdrop), 4497.234393 * 10**6);
  }

  function testRevert_AlreadyClaimed() external {
    bytes32[] memory merkleProof = new bytes32[](1);
    merkleProof[
      0
    ] = 0x29a67c03ffd050f5ef7d29ec5da67725ce281e209a4d795a8d0f1c3295961555;
    merkleAirdrop.claim(
      0,
      0x0578C797798Ae89b688Cd5676348344d7d0EC35E,
      3497234393,
      merkleProof
    );

    assertEq(
      usdc.balanceOf(0x0578C797798Ae89b688Cd5676348344d7d0EC35E),
      3497234393
    );

    vm.expectRevert(abi.encodeWithSignature("MerkleAirdrop_AlreadyClaimed()"));
    merkleAirdrop.claim(
      0,
      0x0578C797798Ae89b688Cd5676348344d7d0EC35E,
      3497234393,
      merkleProof
    );
  }

  function testCorrectness_Claim() external {
    bytes32[] memory merkleProof = new bytes32[](1);
    merkleProof[
      0
    ] = 0x29a67c03ffd050f5ef7d29ec5da67725ce281e209a4d795a8d0f1c3295961555;
    merkleAirdrop.claim(
      0,
      0x0578C797798Ae89b688Cd5676348344d7d0EC35E,
      3497234393,
      merkleProof
    );

    assertEq(
      usdc.balanceOf(0x0578C797798Ae89b688Cd5676348344d7d0EC35E),
      3497234393
    );

    merkleProof[
      0
    ] = 0x4a885167ba8603fa3d196e4460f287b098682ee17f030d9c2ef979244d205a1b;
    merkleAirdrop.claim(
      1,
      0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a,
      1000000000,
      merkleProof
    );

    assertEq(
      usdc.balanceOf(0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a),
      1000000000
    );

    assertEq(usdc.balanceOf(address(merkleAirdrop)), 0);
  }
}

// {
//   "merkleRoot": "0xe8265d62c006291e55af5cc6cde08360d1362af700d61a06087c7ce21b2c31b8",
//   "tokenTotal": "0x010c0e59d9",
//   "claims": {
//     "0x0578c797798ae89b688cd5676348344d7d0ec35e": {
//       "index": 0,
//       "amount": "0xd0738fd9",
//       "proof": [
//         "0x29a67c03ffd050f5ef7d29ec5da67725ce281e209a4d795a8d0f1c3295961555"
//       ]
//     },
//     "0x6629ec35c8aa279ba45dbfb575c728d3812ae31a": {
//       "index": 1,
//       "amount": "0x3b9aca00",
//       "proof": [
//         "0x4a885167ba8603fa3d196e4460f287b098682ee17f030d9c2ef979244d205a1b"
//       ]
//     }
//   }
// }
