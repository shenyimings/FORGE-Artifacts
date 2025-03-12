// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// dependencies
import { IViewFacet } from "@alpaca-mm/money-market/interfaces/IViewFacet.sol";

// contracts
import { Bank } from "src/Bank.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

// libraries
import { LibShareUtil } from "src/libraries/LibShareUtil.sol";

// mocks
import { MockMoneyMarket } from "test/mocks/MockMoneyMarket.sol";

// fixtures
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract BankTest is ProtocolActorFixture {
  using LibShareUtil for uint256;

  Bank bank;
  MockMoneyMarket mockMoneyMarket;
  address mockVaultManager = makeAddr("mockVaultManager");
  address IN_SCOPE_EXECUTOR = makeAddr("IN_SCOPE_EXECUTOR");

  IERC20 wbnb;
  IERC20 usdt;

  constructor() ProtocolActorFixture() {
    wbnb = IERC20(DeployHelper.deployMockERC20("BNB", 18));
    usdt = IERC20(DeployHelper.deployMockERC20("USDT", 6));
  }

  function setUp() public {
    mockMoneyMarket = new MockMoneyMarket();
    deal(address(wbnb), address(mockMoneyMarket), 100_000 ether);
    deal(address(usdt), address(mockMoneyMarket), 100_000 ether);

    // Mock sanity check
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("vaultTokenImplementation()"), abi.encode(address(0)));
    // Deploy bank
    vm.prank(DEPLOYER);
    bank = Bank(
      DeployHelper.deployUpgradeable(
        "Bank", abi.encodeWithSelector(Bank.initialize.selector, address(mockMoneyMarket), mockVaultManager)
      )
    );

    vm.mockCall(
      address(mockVaultManager), abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(IN_SCOPE_EXECUTOR)
    );

    deal(address(wbnb), IN_SCOPE_EXECUTOR, 100_000 ether);
    deal(address(usdt), IN_SCOPE_EXECUTOR, 100_000 ether);
  }

  function testCorrectness_BorrowOnBehalfOf_OneVault_OneToken_WithInterest_ShouldAccountForInterest() public {
    address vault1 = makeAddr("VAULT_1");

    vm.startPrank(IN_SCOPE_EXECUTOR);

    // First borrow
    bank.borrowOnBehalfOf(vault1, address(wbnb), 1 ether);
    // Debt shares and amount should equal to borrowed amount
    (uint256 debtShares, uint256 debtAmount) = bank.getVaultDebt(vault1, address(wbnb));
    assertEq(debtShares, 1 ether);
    assertEq(debtAmount, 1 ether);

    // Borrow on top of old debt without interest
    bank.borrowOnBehalfOf(vault1, address(wbnb), 2 ether);
    // Debt shares and amount should be equal to previously borrowed amount + newly borrowed amount
    (debtShares, debtAmount) = bank.getVaultDebt(vault1, address(wbnb));
    assertEq(debtShares, 1 ether + 2 ether);
    assertEq(debtAmount, 1 ether + 2 ether);

    // Interest accrued
    mockMoneyMarket.pretendAccrueInterest(address(bank), address(wbnb), 0.03 ether);
    // Debt shares should remain the same as before
    // Debt amount should increase by interest amount
    (debtShares, debtAmount) = bank.getVaultDebt(vault1, address(wbnb));
    assertEq(debtShares, 1 ether + 2 ether);
    assertEq(debtAmount, 1 ether + 2 ether + 0.03 ether);

    // Borrow on top of old debt with interest
    bank.borrowOnBehalfOf(vault1, address(wbnb), 3 ether);
    // Debt shares should increase by value slightly less than newly borrowed due to previous debt interest
    // Debt amount should increase by newly borrowed amount
    (debtShares, debtAmount) = bank.getVaultDebt(vault1, address(wbnb));
    assertEq(debtShares, 1 ether + 2 ether + 2.970297029702970298 ether);
    assertEq(debtAmount, 1 ether + 2 ether + 0.03 ether + 3 ether);
  }

  function _doAndAssertBorrowOnBehalfOf(
    address vaultToken,
    address borrowToken,
    uint256 borrowAmount,
    uint256 expectedDebtSharesToIncrease
  ) internal {
    // Assertions
    // - borrower balance increase by input borrow amount
    // - token debt shares increase by expected value
    // - vault debt shares increase by expected value
    // - vault debt amount increase by input borrow amount
    // - mm debt of bank increase by input borrow amount
    // - no funds should remain in bank

    (uint256 prevVaultDebtShares, uint256 prevVaultDebtAmount) = bank.getVaultDebt(vaultToken, borrowToken);
    uint256 prevTokenDebtShares = bank.tokenDebtShares(borrowToken);
    uint256 prevMMDebt = mockMoneyMarket.getNonCollatAccountDebt(address(bank), borrowToken);
    uint256 prevBalance = IERC20(borrowToken).balanceOf(IN_SCOPE_EXECUTOR);

    // Do borrowOnBehalfOf
    vm.prank(IN_SCOPE_EXECUTOR);
    bank.borrowOnBehalfOf(vaultToken, borrowToken, borrowAmount);

    (uint256 newVaultDebtShares, uint256 newVaultDebtAmount) = bank.getVaultDebt(vaultToken, borrowToken);

    // Borrower receive tokens equal to specified borrow amount
    assertEq(IERC20(borrowToken).balanceOf(IN_SCOPE_EXECUTOR) - prevBalance, borrowAmount, "borrower receive tokens");

    // Vault debt shares should increase
    assertEq(newVaultDebtShares - prevVaultDebtShares, expectedDebtSharesToIncrease, "vault debt shares increase");
    // Token debt shares should increase
    assertEq(
      bank.tokenDebtShares(borrowToken) - prevTokenDebtShares,
      expectedDebtSharesToIncrease,
      "token debt shares increase"
    );

    // Vault debt amount should increase by borrowed amount
    // Can tolerate 1 wei precision loss due to share to value conversion
    assertApproxEqAbs(newVaultDebtAmount - prevVaultDebtAmount, borrowAmount, 1, "vault debt amount increase");

    // MM non-collat token debt of bank should increase by borrowed amount
    assertEq(
      mockMoneyMarket.getNonCollatAccountDebt(address(bank), borrowToken) - prevMMDebt, borrowAmount, "mm debt increase"
    );

    // No funds should remain in bank
    assertEq(IERC20(borrowToken).balanceOf(address(bank)), 0);
  }

  function testCorrectness_BorrowOnBehalfOf_ManyVault_ManyTokens_WithInterest() public {
    address vault1 = makeAddr("VAULT_1");
    address vault2 = makeAddr("VAULT_2");

    // Vault 1 first borrow, should get debt shares equal to borrowed amount
    _doAndAssertBorrowOnBehalfOf(vault1, address(wbnb), 1 ether, 1 ether);
    _doAndAssertBorrowOnBehalfOf(vault1, address(usdt), 1 ether, 1 ether);

    // Vault 2 first borrow, should get debt shares equal to borrowed amount
    _doAndAssertBorrowOnBehalfOf(vault2, address(wbnb), 1.5 ether, 1.5 ether);
    _doAndAssertBorrowOnBehalfOf(vault2, address(usdt), 1.5 ether, 1.5 ether);

    // Vault 1 Second borrow, should get debt shares equal to borrowed amount
    _doAndAssertBorrowOnBehalfOf(vault1, address(wbnb), 2 ether, 2 ether);
    _doAndAssertBorrowOnBehalfOf(vault1, address(usdt), 2 ether, 2 ether);

    // Vault 2 Second borrow, should get debt shares equal to borrowed amount
    _doAndAssertBorrowOnBehalfOf(vault2, address(wbnb), 2.5 ether, 2.5 ether);
    _doAndAssertBorrowOnBehalfOf(vault2, address(usdt), 2.5 ether, 2.5 ether);

    // Debt accrue interest
    // 1% interest accrued for wbnb
    mockMoneyMarket.pretendAccrueInterest(address(bank), address(wbnb), 0.07 ether);
    // 3% interest accrued for usdt
    mockMoneyMarket.pretendAccrueInterest(address(bank), address(usdt), 0.21 ether);

    // Borrow when there is interest, should get debt shares that doesn't account for previous borrow interest
    // expectedShares = borrowAmount * tokenDebtShares / mmDebtAmount

    // expectedShares = 1 ether * 7 ether / 7.07 ether
    _doAndAssertBorrowOnBehalfOf(vault1, address(wbnb), 1 ether, 0.9900990099009901 ether);
    // expectedShares = 3 ether * 7 ether / 7.21 ether
    _doAndAssertBorrowOnBehalfOf(vault1, address(usdt), 3 ether, 2.912621359223300971 ether);
  }

  function testCorrectness_RepayOnBehalfOf_OneVault_OneToken_WithInterest_ShouldBeAbleToRepayAllDebt() public {
    address vault1 = makeAddr("VAULT_1");

    vm.startPrank(IN_SCOPE_EXECUTOR);

    wbnb.approve(address(bank), type(uint256).max);

    // Create debt without interest
    bank.borrowOnBehalfOf(vault1, address(wbnb), 2 ether);

    // Repay half of debt
    bank.repayOnBehalfOf(vault1, address(wbnb), 1 ether);
    // Debt shares and amount should reduce by half
    (uint256 debtShares, uint256 debtAmount) = bank.getVaultDebt(vault1, address(wbnb));
    assertEq(debtShares, 1 ether);
    assertEq(debtAmount, 1 ether);

    // Debt accrue interest
    mockMoneyMarket.pretendAccrueInterest(address(bank), address(wbnb), 0.01 ether);

    // Repay half of debt include interest
    bank.repayOnBehalfOf(vault1, address(wbnb), 0.505 ether);
    // Debt shares and amount should reduce by half
    (debtShares, debtAmount) = bank.getVaultDebt(vault1, address(wbnb));
    assertEq(debtShares, 0.5 ether);
    assertEq(debtAmount, 0.505 ether);

    // Repay the rest
    bank.repayOnBehalfOf(vault1, address(wbnb), 0.505 ether);
    // Debt shares and amount should be gone
    (debtShares, debtAmount) = bank.getVaultDebt(vault1, address(wbnb));
    assertEq(debtShares, 0);
    assertEq(debtAmount, 0);
  }

  function _doAndAssertRepayOnBehalfOf(
    address vaultToken,
    address repayToken,
    uint256 repayAmount,
    uint256 expectedDebtSharesToDecrease
  ) internal {
    // Assertions
    // - repayer balance decrease by input repay amount
    // - token debt shares decrease by expected value
    // - vault debt shares decrease by expected value
    // - vault debt amount decrease by input repay amount
    // - mm debt decrease by input repay amount
    // - no funds left in bank

    (uint256 prevVaultDebtShares, uint256 prevVaultDebtAmount) = bank.getVaultDebt(vaultToken, repayToken);
    uint256 prevTokenDebtShares = bank.tokenDebtShares(repayToken);
    uint256 prevMMDebt = mockMoneyMarket.getNonCollatAccountDebt(address(bank), repayToken);
    uint256 prevBalance = IERC20(repayToken).balanceOf(IN_SCOPE_EXECUTOR);

    // Do borrowOnBehalfOf
    vm.startPrank(IN_SCOPE_EXECUTOR);
    IERC20(repayToken).approve(address(bank), type(uint256).max);
    bank.repayOnBehalfOf(vaultToken, repayToken, repayAmount);
    vm.stopPrank();

    (uint256 newVaultDebtShares, uint256 newVaultDebtAmount) = bank.getVaultDebt(vaultToken, repayToken);
    uint256 expectedRepayAmount = prevVaultDebtAmount > repayAmount ? repayAmount : prevVaultDebtAmount;

    // Repayer tokens deducted by specified repay amount
    assertEq(prevBalance - IERC20(repayToken).balanceOf(IN_SCOPE_EXECUTOR), expectedRepayAmount, "repayer pay tokens");

    // Vault debt shares should decrease
    assertEq(prevVaultDebtShares - newVaultDebtShares, expectedDebtSharesToDecrease, "vault debt shares decrease");
    // Token debt shares should decrease
    assertEq(
      prevTokenDebtShares - bank.tokenDebtShares(repayToken), expectedDebtSharesToDecrease, "token debt shares decrease"
    );

    // Vault debt amount should decrease by repaid amount
    // Can tolerate 1 wei precision loss due to share to value conversion
    assertApproxEqAbs(prevVaultDebtAmount - newVaultDebtAmount, expectedRepayAmount, 1, "vault debt amount decrease");

    // MM non-collat token debt of bank should decrease by borrowed amount
    assertEq(
      prevMMDebt - mockMoneyMarket.getNonCollatAccountDebt(address(bank), repayToken),
      expectedRepayAmount,
      "mm debt decrease"
    );

    // No funds should remain in bank
    assertEq(IERC20(repayToken).balanceOf(address(bank)), 0);
  }

  function testCorrectness_RepayOnBehalfOf_ManyVault_ManyToken_WithInterest() public {
    address vault1 = makeAddr("VAULT_1");
    address vault2 = makeAddr("VAULT_2");

    vm.startPrank(IN_SCOPE_EXECUTOR);

    // Create debt without interest
    bank.borrowOnBehalfOf(vault1, address(wbnb), 1 ether);
    bank.borrowOnBehalfOf(vault1, address(usdt), 1 ether);
    bank.borrowOnBehalfOf(vault2, address(wbnb), 2 ether);
    bank.borrowOnBehalfOf(vault2, address(usdt), 2 ether);
    vm.stopPrank();

    // Vault 1 repay half while no interest, debt shares should decrease by repay amount
    _doAndAssertRepayOnBehalfOf(vault1, address(wbnb), 0.5 ether, 0.5 ether);
    _doAndAssertRepayOnBehalfOf(vault1, address(usdt), 0.5 ether, 0.5 ether);
    // Vault 2 repay half while no interest, debt shares should decrease by repay amount
    _doAndAssertRepayOnBehalfOf(vault2, address(wbnb), 1 ether, 1 ether);
    _doAndAssertRepayOnBehalfOf(vault2, address(usdt), 1 ether, 1 ether);

    // Debt accrue interest
    // 1% interest accrued for wbnb
    mockMoneyMarket.pretendAccrueInterest(address(bank), address(wbnb), 0.015 ether);
    // 3% interest accrued for usdt
    mockMoneyMarket.pretendAccrueInterest(address(bank), address(usdt), 0.045 ether);

    // Repay when there is interest
    // reducedShares = repayAmount * tokenDebtShares / mmDebtAmount

    // Vault 1 repay the rest with interest
    // reducedShares = 0.505 ether * 1.5 ether / 1.515 ether
    _doAndAssertRepayOnBehalfOf(vault1, address(wbnb), 0.505 ether, 0.5 ether);
    // reducedShares = 0.515 ether * 1.5 ether / 1.545 ether
    _doAndAssertRepayOnBehalfOf(vault1, address(usdt), 0.515 ether, 0.5 ether);

    // Vault 2 repay the rest with interest
    // reducedShares = 1.01 ether * 1 ether / 1.01 ether
    _doAndAssertRepayOnBehalfOf(vault2, address(wbnb), 1.01 ether, 1 ether);
    // reducedShares = 1.03 ether * 1 ether / 1.03 ether
    _doAndAssertRepayOnBehalfOf(vault2, address(usdt), 1.03 ether, 1 ether);

    // There should be no debt left
    (uint256 debtShares, uint256 debtAmount) = bank.getVaultDebt(vault1, address(wbnb));
    assertEq(debtShares, 0);
    assertEq(debtAmount, 0);
    (debtShares, debtAmount) = bank.getVaultDebt(vault1, address(usdt));
    assertEq(debtShares, 0);
    assertEq(debtAmount, 0);
    (debtShares, debtAmount) = bank.getVaultDebt(vault2, address(wbnb));
    assertEq(debtShares, 0);
    assertEq(debtAmount, 0);
    (debtShares, debtAmount) = bank.getVaultDebt(vault2, address(usdt));
    assertEq(debtShares, 0);
    assertEq(debtAmount, 0);
  }

  function testFuzz_RepayOnBehalfOf_RepayMoreThanDebt(uint256 borrowAmount, uint256 repayAmount) public {
    borrowAmount = bound(borrowAmount, 1e6, 1e24);
    repayAmount = bound(repayAmount, borrowAmount, type(uint256).max);

    address vault1 = makeAddr("VAULT_1");
    deal(address(wbnb), address(mockMoneyMarket), borrowAmount);

    // Create debt without interest
    _doAndAssertBorrowOnBehalfOf(vault1, address(wbnb), borrowAmount, borrowAmount);

    // Repay more than debt
    _doAndAssertRepayOnBehalfOf(vault1, address(wbnb), repayAmount, borrowAmount);

    // There should be no debt left
    (uint256 debtShares, uint256 debtAmount) = bank.getVaultDebt(vault1, address(wbnb));
    assertEq(debtShares, 0);
    assertEq(debtAmount, 0);
  }

  function testCorrectness_AccrueInterest() public {
    address vault1 = makeAddr("VAULT_1");

    vm.startPrank(IN_SCOPE_EXECUTOR);
    bank.borrowOnBehalfOf(vault1, address(wbnb), 1 ether);
    bank.borrowOnBehalfOf(vault1, address(usdt), 1 ether);

    vm.expectCall(address(mockMoneyMarket), abi.encodeCall(mockMoneyMarket.accrueInterest, (address(wbnb))), 1);
    vm.expectCall(address(mockMoneyMarket), abi.encodeCall(mockMoneyMarket.accrueInterest, (address(usdt))), 1);
    bank.accrueInterest(vault1);
  }
}
