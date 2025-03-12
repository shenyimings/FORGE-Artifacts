// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../BaseUnit.GSquared.t.sol";


contract RouterUnitTest is BaseUnitFixture {
    function setUp() public virtual override {
        BaseUnitFixture.setUp();
    }

    function testDepositUnitSimple(uint256 seniorDeposit, uint256 juniorDeposit) public {
        vm.assume(seniorDeposit > 5e19 && seniorDeposit < 1e30);
        vm.assume(juniorDeposit > seniorDeposit && juniorDeposit < 1e35);
        vm.startPrank(alice);

        uint256 juniorFactor = gTranche.factor(0);
        // Make sure tranches are empty before Alice deposit
        assertEq(gTranche.trancheBalances(1), 0);
        assertEq(gTranche.trancheBalances(0), 0);
        // Deal some DAI to alice
        dai.faucet(type(uint256).max / 2);
        uint256 aliceInitBalance = dai.balanceOf(alice);
        dai.approve(address(gRouter), type(uint256).max);
        gRouter.deposit(juniorDeposit, 0, false, 0);
        gRouter.deposit(seniorDeposit, 0, true, 0);
        vm.stopPrank();

        assertEq(dai.balanceOf(alice), aliceInitBalance - juniorDeposit - seniorDeposit);
        // Check that tranche USD balances are updated
        assertApproxEqAbs(gTranche.trancheBalances(1), seniorDeposit, 1);
        assertApproxEqAbs(gTranche.trancheBalances(0), juniorDeposit, 1);
        // Senior tranche is mapped 1:1
        assertApproxEqAbs(gTranche.balanceOfWithFactor(alice, 1), seniorDeposit, 1);
        // Junior balance of Alice is calculated as jun deposit multiplied by base junior factor
        assertApproxEqAbs(gTranche.balanceOfWithFactor(alice, 0), juniorDeposit * juniorFactor / 1e18, 1);
    }

    function testWithdrawalUnitSimple(uint256 seniorDeposit, uint256 juniorDeposit) public {
        vm.assume(seniorDeposit > 5e19 && seniorDeposit < 1e30);
        vm.assume(juniorDeposit > seniorDeposit && juniorDeposit < 1e35);
        vm.startPrank(alice);
        // Allow Router to use Alice's GERC1155 tokens
        gTranche.setApprovalForAll(address(gRouter), true);

        uint256 juniorFactor = gTranche.factor(0);
        // Make sure tranches are empty before Alice deposit
        assertEq(gTranche.trancheBalances(1), 0);
        assertEq(gTranche.trancheBalances(0), 0);
        // Deal some DAI to alice
        dai.faucet(type(uint256).max / 2);
        uint256 aliceInitBalance = dai.balanceOf(alice);
        dai.approve(address(gRouter), type(uint256).max);
        gRouter.deposit(juniorDeposit, 0, false, 0);
        gRouter.deposit(seniorDeposit, 0, true, 0);
        // Check Alice balance
        uint256 aliceBalanceSnapshot = aliceInitBalance - juniorDeposit - seniorDeposit;
        assertEq(dai.balanceOf(alice), aliceBalanceSnapshot);
        assertApproxEqAbs(gTranche.trancheBalances(1), seniorDeposit, 1);
        // Withdraw half of senior deposit
        gRouter.withdraw(seniorDeposit / 2, 0, true, 0);
        vm.stopPrank();

        // Check Alice balance in DAI
        assertGt(dai.balanceOf(alice), aliceBalanceSnapshot);
        // Check Alice balance
        assertApproxEqAbs(gTranche.balanceOfWithFactor(alice, 1), seniorDeposit / 2, 1);
        // Check that tranche USD balances are updated
        assertApproxEqAbs(gTranche.trancheBalances(1), seniorDeposit / 2, 1);
    }
}