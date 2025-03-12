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

contract MerkleAirdrop_EmergencyWithdraw is MerkleAirdrop_BaseTest {
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

  function testRevert_NotOwner() external {
    vm.prank(ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    merkleAirdrop.emergencyWithdraw(ALICE);
  }

  function testCorrectness_Claim() external {
    merkleAirdrop.emergencyWithdraw(ALICE);

    assertEq(usdc.balanceOf(ALICE), referralAmountWeek1 + referralAmountWeek2);
  }
}
