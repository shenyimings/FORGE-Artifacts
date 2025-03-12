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
import { BaseTest, console, MerkleAirdrop } from "../base/BaseTest.sol";

abstract contract MerkleAirdrop_BaseTest is BaseTest {
  MerkleAirdrop internal merkleAirdrop;
  bytes32 internal merkleRoot1 =
    0xe8265d62c006291e55af5cc6cde08360d1362af700d61a06087c7ce21b2c31b8;
  bytes32 internal merkleRoot2 =
    0xf0dbaa7f88c63decfc5d7e55ccc1de12c448ace714613b80dbd431c3d7cb40f2;
  bytes32 internal salt = keccak256("1");
  bytes32 internal ipfsHash = keccak256("1");
  uint256 internal weekTimestamp1 = 1 weeks / 1 weeks;
  uint256 internal weekTimestamp2 = 2 weeks / 1 weeks;
  uint256 internal referralAmountWeek1 = 4497.234393 * 10**6;
  uint256 internal referralAmountWeek2 = 500 * 10**6;

  function setUp() public virtual {
    merkleAirdrop = deployMerkleAirdrop(address(usdc), address(this));
  }
}
