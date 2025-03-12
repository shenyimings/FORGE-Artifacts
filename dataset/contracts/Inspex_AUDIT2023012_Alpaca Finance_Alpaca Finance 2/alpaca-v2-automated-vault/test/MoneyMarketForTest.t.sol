// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { MoneyMarketForTest } from "src/MoneyMarketForTest.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

contract MoneyMarketForTestTest is Test {
  MoneyMarketForTest moneyMarket;
  address mockBank = makeAddr("mockBank");
  MockERC20 mockToken0;
  MockERC20 mockToken1;
  uint256 constant INTEREST_RATE_PER_SEC = 2536783358; // 8% per year

  function setUp() public {
    moneyMarket = new MoneyMarketForTest();
    moneyMarket.setInterestRatePerSec(INTEREST_RATE_PER_SEC);
    moneyMarket.setBorrower(mockBank);
    mockToken0 = new MockERC20("mock0", "mock0", 18);
    mockToken1 = new MockERC20("mock1", "mock1", 6);
  }

  function testCorrectness_nonCollatBorrow_nonCollatRepay_accrueInterest() public {
    deal(address(mockToken0), address(moneyMarket), 1 ether);

    vm.startPrank(mockBank);
    moneyMarket.nonCollatBorrow(address(mockToken0), 1 ether);

    assertEq(mockToken0.balanceOf(mockBank), 1 ether);
    assertEq(mockToken0.balanceOf(address(moneyMarket)), 0);
    assertEq(moneyMarket.getNonCollatAccountDebt(mockBank, address(mockToken0)), 1 ether);
    assertEq(moneyMarket.lastAccrualOf(address(mockToken0)), block.timestamp);

    skip(100);
    uint256 interest = 100 * INTEREST_RATE_PER_SEC;
    deal(address(mockToken0), mockBank, mockToken0.balanceOf(mockBank) + interest);

    mockToken0.approve(address(moneyMarket), 1 ether + interest);
    moneyMarket.nonCollatRepay(mockBank, address(mockToken0), 1 ether + interest);

    assertEq(mockToken0.balanceOf(mockBank), 0);
    assertEq(mockToken0.balanceOf(address(moneyMarket)), 1 ether + interest);
    assertEq(moneyMarket.getNonCollatAccountDebt(mockBank, address(mockToken0)), 0);
    assertEq(moneyMarket.lastAccrualOf(address(mockToken0)), block.timestamp);
  }

  function testCorrectness_withdrawTokens() public {
    deal(address(mockToken0), address(moneyMarket), 1 ether);
    deal(address(mockToken1), address(moneyMarket), 1e6);

    address[] memory tokens = new address[](2);
    tokens[0] = address(mockToken0);
    tokens[1] = address(mockToken1);
    moneyMarket.withdrawTokens(tokens);

    assertEq(mockToken0.balanceOf(address(this)), 1 ether);
    assertEq(mockToken1.balanceOf(address(this)), 1e6);
  }

  function testCorrectness_accessControl() public {
    vm.startPrank(address(1234));

    address[] memory tokens = new address[](1);
    tokens[0] = address(mockToken0);
    vm.expectRevert(bytes("NO"));
    moneyMarket.withdrawTokens(tokens);

    vm.expectRevert(bytes("NB"));
    moneyMarket.nonCollatBorrow(address(1234), 1);

    vm.expectRevert(bytes("NO"));
    moneyMarket.setInterestRatePerSec(1);
  }

  function testCorrectness_injectFund() public {
    uint256 _mmBalanceBefore = mockToken0.balanceOf(address(moneyMarket));
    deal(address(mockToken0), address(this), 1 ether);

    mockToken0.approve(address(moneyMarket), 1 ether);

    moneyMarket.injectFund(address(mockToken0), 1 ether);

    assertEq(mockToken0.balanceOf(address(moneyMarket)) - _mmBalanceBefore, 1 ether);
  }
}
