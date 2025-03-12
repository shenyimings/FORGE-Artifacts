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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleAirdrop_BaseTest, MerkleAirdrop } from "./MerkleAirdrop_BaseTest.t.sol";

contract MerkleAirdrop_BulkClaim is MerkleAirdrop_BaseTest {
  function setUp() public override {
    super.setUp();
    vm.warp(3 weeks);
    merkleAirdrop.init(weekTimestamp1, merkleRoot1);
    merkleAirdrop.init(weekTimestamp2, merkleRoot2);
    usdc.mint(address(this), referralAmountWeek1 + referralAmountWeek2);
    usdc.transfer(
      address(merkleAirdrop),
      referralAmountWeek1 + referralAmountWeek2
    );
  }

  function testRevert_AlreadyClaimed() external {
    uint256[] memory weekTimestamps = new uint256[](4);
    weekTimestamps[0] = weekTimestamp1;
    weekTimestamps[1] = weekTimestamp1;
    weekTimestamps[2] = weekTimestamp2;
    weekTimestamps[3] = weekTimestamp2;

    uint256[] memory indices = new uint256[](4);
    indices[0] = 0;
    indices[1] = 1;
    indices[2] = 0;
    indices[3] = 1;

    address[] memory accounts = new address[](4);
    accounts[0] = 0x0578C797798Ae89b688Cd5676348344d7d0EC35E;
    accounts[1] = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a;
    accounts[2] = 0x0578C797798Ae89b688Cd5676348344d7d0EC35E;
    accounts[3] = 0xac0E15a038eedfc68ba3C35c73feD5bE4A07afB5;

    uint256[] memory amounts = new uint256[](4);
    amounts[0] = 3497234393;
    amounts[1] = 1000000000;
    amounts[2] = 100000000;
    amounts[3] = 400000000;

    bytes32[][] memory merkleProofs = new bytes32[][](4);
    merkleProofs[0] = new bytes32[](1);
    merkleProofs[0][
      0
    ] = 0x29a67c03ffd050f5ef7d29ec5da67725ce281e209a4d795a8d0f1c3295961555;
    merkleProofs[1] = new bytes32[](1);
    merkleProofs[1][
      0
    ] = 0x4a885167ba8603fa3d196e4460f287b098682ee17f030d9c2ef979244d205a1b;
    merkleProofs[2] = new bytes32[](1);
    merkleProofs[2][
      0
    ] = 0x0764744763c44790e1c67fdb1980737eb59172fb8ff8bfff04af46d2cb00edaa;
    merkleProofs[3] = new bytes32[](1);
    merkleProofs[3][
      0
    ] = 0x2093264bdce01a9e25cba43ac765a683400dddee4d41a092fc95f40d18d3cd8d;

    merkleAirdrop.bulkClaim(
      weekTimestamps,
      indices,
      accounts,
      amounts,
      merkleProofs
    );

    vm.expectRevert(abi.encodeWithSignature("MerkleAirdrop_AlreadyClaimed()"));
    merkleAirdrop.bulkClaim(
      weekTimestamps,
      indices,
      accounts,
      amounts,
      merkleProofs
    );
  }

  function testCorrectness_BulkClaim() external {
    uint256[] memory weekTimestamps = new uint256[](4);
    weekTimestamps[0] = weekTimestamp1;
    weekTimestamps[1] = weekTimestamp1;
    weekTimestamps[2] = weekTimestamp2;
    weekTimestamps[3] = weekTimestamp2;

    uint256[] memory indices = new uint256[](4);
    indices[0] = 0;
    indices[1] = 1;
    indices[2] = 0;
    indices[3] = 1;

    address[] memory accounts = new address[](4);
    accounts[0] = 0x0578C797798Ae89b688Cd5676348344d7d0EC35E;
    accounts[1] = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a;
    accounts[2] = 0x0578C797798Ae89b688Cd5676348344d7d0EC35E;
    accounts[3] = 0xac0E15a038eedfc68ba3C35c73feD5bE4A07afB5;

    uint256[] memory amounts = new uint256[](4);
    amounts[0] = 3497234393;
    amounts[1] = 1000000000;
    amounts[2] = 100000000;
    amounts[3] = 400000000;

    bytes32[][] memory merkleProofs = new bytes32[][](4);
    merkleProofs[0] = new bytes32[](1);
    merkleProofs[0][
      0
    ] = 0x29a67c03ffd050f5ef7d29ec5da67725ce281e209a4d795a8d0f1c3295961555;
    merkleProofs[1] = new bytes32[](1);
    merkleProofs[1][
      0
    ] = 0x4a885167ba8603fa3d196e4460f287b098682ee17f030d9c2ef979244d205a1b;
    merkleProofs[2] = new bytes32[](1);
    merkleProofs[2][
      0
    ] = 0x0764744763c44790e1c67fdb1980737eb59172fb8ff8bfff04af46d2cb00edaa;
    merkleProofs[3] = new bytes32[](1);
    merkleProofs[3][
      0
    ] = 0x2093264bdce01a9e25cba43ac765a683400dddee4d41a092fc95f40d18d3cd8d;

    merkleAirdrop.bulkClaim(
      weekTimestamps,
      indices,
      accounts,
      amounts,
      merkleProofs
    );

    assertEq(
      usdc.balanceOf(0x0578C797798Ae89b688Cd5676348344d7d0EC35E),
      100000000 + 3497234393
    );
    assertEq(
      usdc.balanceOf(0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a),
      1000000000
    );
    assertEq(
      usdc.balanceOf(0xac0E15a038eedfc68ba3C35c73feD5bE4A07afB5),
      400000000
    );
    assertEq(usdc.balanceOf(address(merkleAirdrop)), 0);
  }
}

// Merkle Tree 1
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

// Merkle Tree 2
// {
//   "merkleRoot": "0xf0dbaa7f88c63decfc5d7e55ccc1de12c448ace714613b80dbd431c3d7cb40f2",
//   "tokenTotal": "0x1dcd6500",
//   "claims": {
//     "0x0578c797798ae89b688cd5676348344d7d0ec35e": {
//       "index": 0,
//       "amount": "0x05f5e100",
//       "proof": [
//         "0x0764744763c44790e1c67fdb1980737eb59172fb8ff8bfff04af46d2cb00edaa"
//       ]
//     },
//     "0xac0e15a038eedfc68ba3c35c73fed5be4a07afb5": {
//       "index": 1,
//       "amount": "0x17d78400",
//       "proof": [
//         "0x2093264bdce01a9e25cba43ac765a683400dddee4d41a092fc95f40d18d3cd8d"
//       ]
//     }
//   }
// }
