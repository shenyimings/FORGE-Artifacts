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

import { ALPStaking } from "../../staking/ALPStaking.sol";
import { BaseTest } from "../base/BaseTest.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { MockRewarder } from "../mocks/MockRewarder.sol";

contract ALPStakingTest is BaseTest {
  ALPStaking internal staking;

  MockErc20 internal alp;
  MockErc20 internal alpaca;

  MockRewarder internal protocolRevenueRewarder;
  MockRewarder internal mockRewarder;
  MockRewarder internal partnerRewarder;

  function setUp() external {
    alp = new MockErc20("ALP Token", "ALP", 18);
    alpaca = new MockErc20("ALPACA Token", "ALAPCA", 18);

    protocolRevenueRewarder = new MockRewarder();
    mockRewarder = new MockRewarder();
    partnerRewarder = new MockRewarder();

    address[] memory rewarders1 = new address[](3);
    rewarders1[0] = address(protocolRevenueRewarder);
    rewarders1[1] = address(mockRewarder);
    rewarders1[2] = address(partnerRewarder);

    staking = deployALPStaking();
    staking.addStakingToken(address(alp), rewarders1);

    alp.mint(ALICE, 100 ether);
    alp.mint(BOB, 100 ether);
    alpaca.mint(BOB, 100 ether);
  }

  function deployALPStaking() internal returns (ALPStaking) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/ALPStaking.sol/ALPStaking.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize()"))
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return ALPStaking(payable(_proxy));
  }

  function testRevert_NotStakingToken_WhenAliceDeposit() external {
    vm.expectRevert(
      abi.encodeWithSignature("ALPStaking_UnknownStakingToken()")
    );
    vm.prank(ALICE);
    staking.deposit(ALICE, address(alpaca), 100 ether);
  }

  function testRevert_InsufficientAllowance_WhenAliceDeposit() external {
    vm.startPrank(ALICE);
    vm.expectRevert("ERC20: insufficient allowance");
    staking.deposit(ALICE, address(alp), 100 ether);
    vm.stopPrank();
  }

  function testRevert_InsufficientBalance_WhenAliceDeposit() external {
    vm.startPrank(ALICE);
    alp.approve(address(staking), 200 ether);
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    staking.deposit(ALICE, address(alp), 200 ether);
    vm.stopPrank();
  }

  function testCorrectness_WhenAliceBobDeposit() external {
    vm.startPrank(BOB);
    alp.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(alp), 100 ether);
    vm.stopPrank();

    assertEq(alp.balanceOf(BOB), 0);
    assertEq(staking.userTokenAmount(address(alp), BOB), 100 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), BOB),
      100 ether
    );
    assertEq(staking.calculateShare(address(mockRewarder), BOB), 100 ether);
    assertEq(staking.calculateShare(address(partnerRewarder), BOB), 100 ether);

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      100 ether
    );
    assertEq(staking.calculateTotalShare(address(mockRewarder)), 100 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 100 ether);

    vm.startPrank(ALICE);
    alp.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(alp), 100 ether);
    vm.stopPrank();

    assertEq(alp.balanceOf(ALICE), 0);
    assertEq(staking.userTokenAmount(address(alp), ALICE), 100 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), ALICE),
      100 ether
    );
    assertEq(staking.calculateShare(address(mockRewarder), ALICE), 100 ether);
    assertEq(
      staking.calculateShare(address(partnerRewarder), ALICE),
      100 ether
    );

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      200 ether
    );
    assertEq(staking.calculateTotalShare(address(mockRewarder)), 200 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 200 ether);
  }

  function testRevert_NotStakingToken_WhenAliceWithdraw() external {
    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("ALPStaking_UnknownStakingToken()")
    );
    staking.withdraw(address(alpaca), 100 ether);
    vm.stopPrank();
  }

  function testRevert_InsufficientBalance_WhenAliceWithdraw() external {
    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("ALPStaking_InsufficientTokenAmount()")
    );
    staking.withdraw(address(alp), 100 ether);
    vm.stopPrank();
  }

  function testCorrectness_WhenAliceBobWithdraw() external {
    vm.startPrank(BOB);
    alp.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(alp), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    alp.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(alp), 100 ether);
    vm.stopPrank();

    vm.prank(BOB);
    staking.withdraw(address(alp), 50 ether);

    assertEq(alp.balanceOf(BOB), 50 ether);
    assertEq(staking.userTokenAmount(address(alp), BOB), 50 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), BOB),
      50 ether
    );
    assertEq(staking.calculateShare(address(mockRewarder), BOB), 50 ether);
    assertEq(staking.calculateShare(address(partnerRewarder), BOB), 50 ether);

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      150 ether
    );
    assertEq(staking.calculateTotalShare(address(mockRewarder)), 150 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 150 ether);

    vm.prank(ALICE);
    staking.withdraw(address(alp), 100 ether);

    assertEq(alp.balanceOf(ALICE), 100 ether);
    assertEq(staking.userTokenAmount(address(alp), ALICE), 0 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), ALICE),
      0 ether
    );
    assertEq(staking.calculateShare(address(mockRewarder), ALICE), 0 ether);
    assertEq(staking.calculateShare(address(partnerRewarder), ALICE), 0 ether);

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      50 ether
    );
    assertEq(staking.calculateTotalShare(address(mockRewarder)), 50 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 50 ether);
  }

  function testCorrectness_WhenAddStakingTokenRewarder() external {
    vm.startPrank(BOB);
    alp.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(alp), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    alp.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(alp), 100 ether);
    vm.stopPrank();

    address[] memory rewarders = new address[](3);
    rewarders[0] = address(protocolRevenueRewarder);
    rewarders[1] = address(mockRewarder);
    rewarders[2] = address(partnerRewarder);
    staking.addStakingToken(address(alpaca), rewarders);

    vm.startPrank(BOB);
    alpaca.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(alpaca), 100 ether);
    vm.stopPrank();

    assertEq(alp.balanceOf(BOB), 0);
    assertEq(staking.userTokenAmount(address(alpaca), BOB), 100 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), BOB),
      200 ether
    );
    assertEq(staking.calculateShare(address(mockRewarder), BOB), 200 ether);
    assertEq(staking.calculateShare(address(partnerRewarder), BOB), 200 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), ALICE),
      100 ether
    );
    assertEq(staking.calculateShare(address(mockRewarder), ALICE), 100 ether);
    assertEq(
      staking.calculateShare(address(partnerRewarder), ALICE),
      100 ether
    );

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      300 ether
    );
    assertEq(staking.calculateTotalShare(address(mockRewarder)), 300 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 300 ether);
  }

  function testCorrectness_WhenAddPartnerRewarder() external {
    MockRewarder P2Rewarder = new MockRewarder();
    address[] memory tokens = new address[](1);
    tokens[0] = address(alp);

    vm.startPrank(BOB);
    alp.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(alp), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    alp.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(alp), 100 ether);
    vm.stopPrank();

    staking.addRewarder(address(P2Rewarder), tokens);

    assertEq(staking.calculateShare(address(P2Rewarder), ALICE), 100 ether);
    assertEq(staking.calculateShare(address(P2Rewarder), BOB), 100 ether);

    assertEq(staking.calculateTotalShare(address(P2Rewarder)), 200 ether);
  }

  function testCorreness_WhenHarvest_WithValidRewarders() external {
    address[] memory rewarders = new address[](4);
    rewarders[0] = address(protocolRevenueRewarder);
    rewarders[1] = address(mockRewarder);
    rewarders[2] = address(partnerRewarder);
    rewarders[3] = address(partnerRewarder); // with duplicate rewarder, should be ok too

    vm.startPrank(ALICE);
    staking.harvest(rewarders);
    vm.stopPrank();
  }

  function testRevert_WhenHarvest_WithInvalidRewarders() external {
    address[] memory rewarders = new address[](1);
    rewarders[0] = address(88); // some random address

    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ALPStaking_NotRewarder()"));
    staking.harvest(rewarders);
    vm.stopPrank();
  }

  function testCorreness_WhenHarvestToCompounder_WithValidRewarders() external {
    address[] memory rewarders = new address[](4);
    rewarders[0] = address(protocolRevenueRewarder);
    rewarders[1] = address(mockRewarder);
    rewarders[2] = address(partnerRewarder);
    rewarders[3] = address(partnerRewarder); // with duplicate rewarder, should be ok too

    address compounder = address(99);
    staking.setCompounder(compounder);

    vm.startPrank(compounder);
    staking.harvestToCompounder(ALICE, rewarders);
    vm.stopPrank();
  }

  function testRevert_WhenHarvestToCompounder_BySomeRandomAccount() external {
    address[] memory rewarders = new address[](0);
    address compounder = address(99);
    staking.setCompounder(compounder);

    vm.startPrank(BOB);
    vm.expectRevert(abi.encodeWithSignature("ALPStaking_NotCompounder()"));
    staking.harvestToCompounder(ALICE, rewarders);
    vm.stopPrank();
  }
}
