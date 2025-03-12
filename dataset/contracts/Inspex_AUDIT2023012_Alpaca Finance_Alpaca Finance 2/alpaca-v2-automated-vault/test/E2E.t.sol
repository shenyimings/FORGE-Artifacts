// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./fixtures/E2EFixture.f.sol";
import { AutomatedVaultManager, MAX_BPS } from "src/AutomatedVaultManager.sol";

import { LibSqrtPriceX96 } from "src/libraries/LibSqrtPriceX96.sol";

contract E2ETest is E2EFixture {
  constructor() E2EFixture() { }

  /// -------------------------------
  /// Test utilities
  /// -------------------------------

  function _depositUSDTAndAssert(address depositor, uint256 amount) internal {
    deal(address(usdt), depositor, amount);

    uint256 sharesBefore = vaultToken.balanceOf(depositor);
    uint256 workerUSDTBefore = usdt.balanceOf(address(workerUSDTWBNB));
    uint256 totalShareBefore = vaultToken.totalSupply();
    (uint256 equityBefore,) = pancakeV3VaultOracle.getEquityAndDebt(address(vaultToken), address(workerUSDTWBNB));
    (, int256 usdtAnswer,,,) = usdtFeed.latestRoundData();
    uint256 expectedEquityIncreased = amount * uint256(usdtAnswer) / (10 ** usdtFeed.decimals());
    uint256 expectedShareIncreased = equityBefore == 0
      ? expectedEquityIncreased
      : expectedEquityIncreased * (totalShareBefore + vaultManager.pendingManagementFee(address(vaultToken)))
        / equityBefore;

    vm.startPrank(depositor);
    usdt.approve(address(vaultManager), amount);

    AutomatedVaultManager.TokenAmount[] memory deposits = new AutomatedVaultManager.TokenAmount[](1);
    deposits[0] = AutomatedVaultManager.TokenAmount({ token: address(usdt), amount: amount });
    vaultManager.deposit(depositor, address(vaultToken), deposits, 0);
    vm.stopPrank();

    // Assertions
    // - undeployed usdt increase by deposited amount
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)) - workerUSDTBefore, amount, "undeployed usdt increase");
    // - shares minted to depositor equal to usd value of 1 usdt (equity)
    assertEq(vaultToken.balanceOf(depositor) - sharesBefore, expectedShareIncreased, "shares received");
  }

  function _withdrawAndAssert(address withdrawFor, uint256 withdrawAmount) internal {
    {
      uint256 sharesBefore = vaultToken.balanceOf(withdrawFor);
      IPancakeV3MasterChef.UserPositionInfo memory userInfoBefore =
        pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
      (, uint256 wbnbDebtBefore) = bank.getVaultDebt(address(vaultToken), address(wbnb));
      (, uint256 usdtDebtBefore) = bank.getVaultDebt(address(vaultToken), address(usdt));
      uint256 workerUSDTBefore = usdt.balanceOf(address(workerUSDTWBNB));
      uint256 workerWBNBBefore = wbnb.balanceOf(address(workerUSDTWBNB));
      (uint256 equityBefore,) = pancakeV3VaultOracle.getEquityAndDebt(address(vaultToken), address(workerUSDTWBNB));
      uint256 totalSharesBefore = vaultToken.totalSupply() + vaultManager.pendingManagementFee(address(vaultToken));

      AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](2);
      minAmountOuts[0].token = address(usdt);
      minAmountOuts[0].amount = 0;
      minAmountOuts[1].token = address(wbnb);
      minAmountOuts[1].amount = 0;
      vm.prank(withdrawFor);
      vaultManager.withdraw(address(vaultToken), withdrawAmount, minAmountOuts);

      uint256 totalSharesAfter = vaultToken.totalSupply();

      // Assertions
      // didn't assert user balance due withdraw in and out of range result are different
      // - user shares was burned
      assertEq(sharesBefore - vaultToken.balanceOf(withdrawFor), withdrawAmount, "shares burned");
      // - position decreased by withdrawn%
      IPancakeV3MasterChef.UserPositionInfo memory userInfoAfter =
        pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
      assertApproxEqAbs(
        userInfoBefore.liquidity * totalSharesAfter / totalSharesBefore,
        userInfoAfter.liquidity,
        1,
        "liquidity decreased"
      );
      // - debt repaid by withdrawn%
      (, uint256 usdtDebtAfter) = bank.getVaultDebt(address(vaultToken), address(usdt));
      assertEq(usdtDebtBefore * totalSharesAfter / totalSharesBefore, usdtDebtAfter, "usdt repaid");
      (, uint256 wbnbDebtAfter) = bank.getVaultDebt(address(vaultToken), address(wbnb));
      assertEq(wbnbDebtBefore * totalSharesAfter / totalSharesBefore, wbnbDebtAfter, "wbnb repaid");
      // - undeployed funds decreased by withdrawn% (management fee will occur precision loss)

      uint256 expectedUsdtRemaining = (workerUSDTBefore * totalSharesAfter) / totalSharesBefore;
      uint256 expectedWbnbRemaining = (workerWBNBBefore * totalSharesAfter) / totalSharesBefore;

      // expect that maximum precision loss will be 1 wei
      assertApproxEqAbs(usdt.balanceOf(address(workerUSDTWBNB)), expectedUsdtRemaining, 1, "undeployed usdt withdrawn");
      assertApproxEqAbs(wbnb.balanceOf(address(workerUSDTWBNB)), expectedWbnbRemaining, 1, "undeployed wbnb withdrawn");

      // - equity reduced by approx withdrawn%
      (uint256 equityAfter,) = pancakeV3VaultOracle.getEquityAndDebt(address(vaultToken), address(workerUSDTWBNB));
      assertApproxEqRel(equityBefore * totalSharesAfter / totalSharesBefore, equityAfter, 2, "equity decreased");
    }

    (,,,, uint256 withdrawalFeeBps,,,,,,,) = vaultManager.vaultInfos(address(vaultToken));
    uint256 expectedShare = withdrawAmount * withdrawalFeeBps / MAX_BPS;

    // expect that withdrawal fee must be collected (if it's set)
    assertEq(vaultToken.balanceOf(WITHDRAWAL_FEE_TREASURY), expectedShare);
  }

  /// -------------------------------
  /// Test cases
  /// -------------------------------

  function testCorrectness_Deposit_WhitelistedToken() public {
    _depositUSDTAndAssert(address(this), 1 ether);
  }

  function testRevert_Deposit_NonWhitelistedToken() public {
    // Blacklist usdt
    vm.prank(DEPLOYER);
    vaultManager.setAllowToken(address(vaultToken), address(usdt), false);

    deal(address(usdt), address(this), 1 ether);

    usdt.approve(address(vaultManager), 1 ether);
    AutomatedVaultManager.TokenAmount[] memory deposits = new AutomatedVaultManager.TokenAmount[](1);
    deposits[0] = AutomatedVaultManager.TokenAmount({ token: address(usdt), amount: 1 ether });
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_TokenNotAllowed.selector);
    vaultManager.deposit(address(this), address(vaultToken), deposits, 0);
  }

  function testRevert_Deposit_EquityIncreaseLessThanMinDeposit() public {
    // MIN_DEPOSIT = 0.1 ether. set in E2Efixture.
    deal(address(usdt), address(this), 0.01 ether);

    usdt.approve(address(vaultManager), 0.01 ether);
    AutomatedVaultManager.TokenAmount[] memory deposits = new AutomatedVaultManager.TokenAmount[](1);
    deposits[0] = AutomatedVaultManager.TokenAmount({ token: address(usdt), amount: 0.01 ether });
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_BelowMinimumDeposit.selector);
    vaultManager.deposit(address(this), address(vaultToken), deposits, 0);
  }

  function testCorrectness_Withdraw_All_NoUndeployedFunds_OnlyInPosition() public {
    _depositUSDTAndAssert(address(this), 1 ether);

    // Borrow and open in-range position
    deal(address(wbnb), address(moneyMarket), 0.01 ether);
    bytes[] memory executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.01 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 1 ether, 0.01 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    uint256 usdtBefore = usdt.balanceOf(address(this));
    uint256 wbnbBefore = wbnb.balanceOf(address(this));

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)));
    // - user received usdt but not wbnb
    assertGt(usdt.balanceOf(address(this)), usdtBefore);
    assertEq(wbnb.balanceOf(address(this)), wbnbBefore);
  }

  function testCorrectness_Withdraw_Partial_UndeployedFundsGtWithdraw() public {
    // Deposit 100 USDT
    // Deploy only 30 USDT => 70 USDT undeployed
    // Withdraw 1 USDT

    _depositUSDTAndAssert(address(this), 100 ether);

    // Borrow and open in-range position
    deal(address(wbnb), address(moneyMarket), 0.1 ether);
    bytes[] memory executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.1 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 30 ether, 0.1 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    uint256 userUSDTBefore = usdt.balanceOf(address(this));
    uint256 userWBNBBefore = wbnb.balanceOf(address(this));

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)) / 100);
    // - user receive both tokens due to being in-range and partial withdraw
    assertGt(usdt.balanceOf(address(this)), userUSDTBefore);
    assertGt(wbnb.balanceOf(address(this)), userWBNBBefore);
  }

  function testCorrectness_Withdraw_Partial_UndeployedFundsLtWithdraw() public {
    // Deposit 100 USDT
    // Deploy 99.9 USDT => 0.1 USDT undeployed
    // Withdraw ~1 USDT

    _depositUSDTAndAssert(address(this), 100 ether);

    // Borrow and open in-range position
    deal(address(wbnb), address(moneyMarket), 0.3 ether);
    bytes[] memory executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.3 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 99.9 ether, 0.3 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    uint256 userUSDTBefore = usdt.balanceOf(address(this));
    uint256 userWBNBBefore = wbnb.balanceOf(address(this));

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)) / 100);
    // - user receive both tokens due to being in-range and partial withdraw
    assertGt(usdt.balanceOf(address(this)), userUSDTBefore);
    assertGt(wbnb.balanceOf(address(this)), userWBNBBefore);
  }

  function testRevert_Withdraw_MoreThanSharesOwned() public {
    // Deposit 1 USDT should get ~1 share
    // Withdraw 2 share should revert

    _depositUSDTAndAssert(address(this), 1 ether);

    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_WithdrawExceedBalance.selector);
    AutomatedVaultManager.TokenAmount[] memory minAmountOuts;
    vaultManager.withdraw(address(vaultToken), 2 ether, minAmountOuts);
  }

  function testRevert_Manage_TooMuchEquityLoss() public {
    // Deposit 1 USDT
    // Borrow 0.1 WBNB
    // Open in-range position
    // Should fail due to zap in swap fee eat into equity too much

    _depositUSDTAndAssert(address(this), 1 ether);

    deal(address(wbnb), address(moneyMarket), 0.1 ether);
    bytes[] memory executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.1 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 1 ether, 0.1 ether));
    vm.prank(MANAGER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_TooMuchEquityLoss.selector);
    vaultManager.manage(address(vaultToken), executorData);
  }

  function testCorrectness_Manage_OpenPosition_ThenBorrowAndIncrease() public {
    _depositUSDTAndAssert(address(this), 100 ether);

    // Open position with 100 USDT
    bytes[] memory executorData = new bytes[](1);
    executorData[0] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 100 ether, 0));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);
    // Assertions
    // - worker `nftTokenId` is 46528
    assertEq(workerUSDTWBNB.nftTokenId(), 46528);
    // - nft is staked with masterChef with correct tick
    IPancakeV3MasterChef.UserPositionInfo memory userInfoAtOpen =
      pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
    assertEq(userInfoAtOpen.user, address(workerUSDTWBNB));
    assertGt(userInfoAtOpen.liquidity, 0);
    assertEq(userInfoAtOpen.tickLower, -58000);
    assertEq(userInfoAtOpen.tickUpper, -57750);

    // Borrow 0.3 WBNB and increase position
    deal(address(wbnb), address(moneyMarket), 0.3 ether);
    executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.3 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.increasePosition, (0, 0.3 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);
    // Assertions
    // - wbnb debt increased
    (, uint256 wbnbDebt) = bank.getVaultDebt(address(vaultToken), address(wbnb));
    assertEq(wbnbDebt, 0.3 ether);
    // - staked nft liquidity increased
    IPancakeV3MasterChef.UserPositionInfo memory userInfoAtIncrease =
      pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
    assertGt(userInfoAtIncrease.liquidity, userInfoAtOpen.liquidity);
    // Invariants
    // - worker `nftTokenId` unchanged
    assertEq(workerUSDTWBNB.nftTokenId(), 46528);
    // - tick unchanged
    assertEq(userInfoAtOpen.tickLower, userInfoAtIncrease.tickLower);
    assertEq(userInfoAtOpen.tickUpper, userInfoAtIncrease.tickUpper);
    // - usdt debt unchanged
    (, uint256 usdtDebt) = bank.getVaultDebt(address(vaultToken), address(usdt));
    assertEq(usdtDebt, 0);

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)));
  }

  function testCorrectness_Manage_ChangeTick() public {
    _depositUSDTAndAssert(address(this), 100 ether);

    // Open position with 100 USDT
    bytes[] memory executorData = new bytes[](1);
    executorData[0] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 100 ether, 0));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    // Change tick (close position then re-open with different tick)
    // Close position
    executorData = new bytes[](1);
    executorData[0] = abi.encodeCall(PCSV3Executor01.closePosition, ());
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    // Re-open position with all funds from closing
    executorData = new bytes[](1);
    executorData[0] = abi.encodeCall(
      PCSV3Executor01.openPosition,
      (-57870, -57860, usdt.balanceOf(address(workerUSDTWBNB)), wbnb.balanceOf(address(workerUSDTWBNB)))
    );
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);
    // Assertions
    // - got new nft
    assertEq(workerUSDTWBNB.nftTokenId(), 46529);
    // - tick is updated
    IPancakeV3MasterChef.UserPositionInfo memory userInfo =
      pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
    assertEq(userInfo.tickLower, -57870);
    assertEq(userInfo.tickUpper, -57860);

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)));
  }

  function testCorrectness_Manage_DecreasePositionAndRepay() public {
    _depositUSDTAndAssert(address(this), 100 ether);

    // Borrow and open position
    deal(address(wbnb), address(moneyMarket), 0.3 ether);
    bytes[] memory executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.3 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.openPosition, (-57900, -57800, 100 ether, 0.3 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    IPancakeV3MasterChef.UserPositionInfo memory userInfoAtOpen =
      pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());

    // Decrease position
    uint128 liquidityToDecrease = 1000 ether;
    executorData = new bytes[](1);
    executorData[0] = abi.encodeCall(PCSV3Executor01.decreasePosition, (liquidityToDecrease));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);
    // Assertions
    IPancakeV3MasterChef.UserPositionInfo memory userInfo =
      pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
    // - liquidity decreased
    assertEq(userInfoAtOpen.liquidity - userInfo.liquidity, liquidityToDecrease);
    // Invariants
    // - nft still there
    assertEq(workerUSDTWBNB.nftTokenId(), 46528);
    // - tick unchanged
    assertEq(userInfo.tickLower, -57900);
    assertEq(userInfo.tickUpper, -57800);

    // Repay
    executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.transferFromWorker, (address(wbnb), 0.01 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.repay, (address(wbnb), 0.01 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);
    // Assertions
    // - wbnb debt repaid
    (, uint256 wbnbDebt) = bank.getVaultDebt(address(vaultToken), address(wbnb));
    assertEq(wbnbDebt, 0.29 ether);
    // Invariants
    // - usdt debt unchanged
    (, uint256 usdtDebt) = bank.getVaultDebt(address(vaultToken), address(usdt));
    assertEq(usdtDebt, 0);

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)));
  }

  function testCorrectness_Manage_ClosePositionAndRepayFull() public {
    _depositUSDTAndAssert(address(this), 100 ether);

    // Borrow and open position
    deal(address(usdt), address(moneyMarket), 100 ether);
    bytes[] memory executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(usdt), 100 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.openPosition, (-57900, -57800, 200 ether, 0));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    uint256 usdtBefore = usdt.balanceOf(address(workerUSDTWBNB));
    uint256 wbnbBefore = wbnb.balanceOf(address(workerUSDTWBNB));

    // Close position
    executorData = new bytes[](1);
    executorData[0] = abi.encodeCall(PCSV3Executor01.closePosition, ());
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);
    // Assertions
    // - worker `nftTokenId` is 0
    assertEq(workerUSDTWBNB.nftTokenId(), 0);
    // - worker balance increase
    assertGt(usdt.balanceOf(address(workerUSDTWBNB)), usdtBefore);
    assertGt(wbnb.balanceOf(address(workerUSDTWBNB)), wbnbBefore);

    // Repay
    executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.transferFromWorker, (address(usdt), 100 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.repay, (address(usdt), 100 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);
    // Assertions
    // - usdt debt all repaid
    (, uint256 usdtDebt) = bank.getVaultDebt(address(vaultToken), address(usdt));
    assertEq(usdtDebt, 0);
    // Invariants
    // - wbnb debt unchanged
    (, uint256 wbnbDebt) = bank.getVaultDebt(address(vaultToken), address(wbnb));
    assertEq(wbnbDebt, 0);

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)));
  }

  // Obsolete case since we don't allow to open out-of-range position
  // function testCorrectness_Manage_ClosePosition_RepayOneSide_BorrowOtherAndOpenOutOfRange() public {
  //   _depositUSDTAndAssert(address(this), 100 ether);

  //   // Borrow wbnb and open position
  //   deal(address(wbnb), address(moneyMarket), 0.1 ether);
  //   bytes[] memory executorData = new bytes[](2);
  //   executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.1 ether));
  //   executorData[2] = abi.encodeCall(PCSV3Executor01.openPosition, (-57900, -57800, 100 ether, 0.1 ether));
  //   vm.prank(MANAGER);
  //   vaultManager.manage(address(vaultToken), executorData);

  //   // Close position
  //   executorData = new bytes[](1);
  //   executorData[0] = abi.encodeCall(PCSV3Executor01.closePosition, ());
  //   vm.prank(MANAGER);
  //   vaultManager.manage(address(vaultToken), executorData);

  //   // Repay wbnb
  //   executorData = new bytes[](2);
  //   executorData[0] = abi.encodeCall(PCSV3Executor01.transferFromWorker, (address(wbnb), 0.1 ether));
  //   executorData[1] = abi.encodeCall(PCSV3Executor01.repay, (address(wbnb), 0.1 ether));
  //   vm.prank(MANAGER);
  //   vaultManager.manage(address(vaultToken), executorData);

  //   // Borrow usdt and open position out-of-range (current tick = -57864)
  //   deal(address(usdt), address(moneyMarket), 100 ether);
  //   executorData = new bytes[](2);
  //   executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(usdt), 100 ether));
  //   executorData[2] = abi.encodeCall(
  //     PCSV3Executor01.openPosition,
  //     (-30000, -20000, usdt.balanceOf(address(workerUSDTWBNB)) + 100 ether, wbnb.balanceOf(address(workerUSDTWBNB)))
  //   );
  //   vm.prank(MANAGER);
  //   vaultManager.manage(address(vaultToken), executorData);

  //   // Assertions
  //   // - usdt debt increase
  //   (, uint256 usdtDebt) = bank.getVaultDebt(address(vaultToken), address(usdt));
  //   assertEq(usdtDebt, 100 ether);
  //   // - wbnb debt all repaid
  //   (, uint256 wbnbDebt) = bank.getVaultDebt(address(vaultToken), address(wbnb));
  //   assertEq(wbnbDebt, 0);
  //   // - liquidity was provided for new position
  //   IPancakeV3MasterChef.UserPositionInfo memory userInfo =
  //     pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
  //   assertGt(userInfo.liquidity, 0);
  //   assertEq(userInfo.tickLower, -30000);
  //   assertEq(userInfo.tickUpper, -20000);

  //   _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)));
  //   // Assertions
  //   // - usdt balance greater than 0
  //   assertGt(usdt.balanceOf(address(this)), 0);
  //   // - wbnb balance 0 due to out of range
  //   assertEq(wbnb.balanceOf(address(this)), 0);
  // }

  function testCorrectness_Manage_Repurchase() public {
    _depositUSDTAndAssert(address(this), 100 ether);

    // Borrow wbnb and open position
    deal(address(wbnb), address(moneyMarket), 0.1 ether);
    bytes[] memory executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.1 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.openPosition, (-57900, -57700, 100 ether, 0.1 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    // Borrow usdt, swap and repay wbnb debt
    deal(address(usdt), address(moneyMarket), 1 ether);
    executorData = new bytes[](1);
    executorData[0] = abi.encodeCall(PCSV3Executor01.repurchase, (address(usdt), 1 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);
    // Assertions
    // - usdt debt increase
    (, uint256 usdtDebt) = bank.getVaultDebt(address(vaultToken), address(usdt));
    assertEq(usdtDebt, 1 ether);
    // - wbnb debt repaid
    (, uint256 wbnbDebt) = bank.getVaultDebt(address(vaultToken), address(wbnb));
    assertEq(wbnbDebt, 0.1 ether - 3068419127879438); // 3068419127879438 is usdt to wbnb swap output

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)));
  }

  function testCorrectness_WhenWithdraw_WithdrawalFee_ShouldBeCollected() public {
    uint256 depositAmount = 100 ether;
    uint16 withdrawalfeeBps = 100;

    // set fee
    vm.prank(DEPLOYER);
    // 1% withdrawal fee
    vaultManager.setWithdrawalFeeBps(address(vaultToken), withdrawalfeeBps);

    // deposit
    _depositUSDTAndAssert(address(this), depositAmount);

    uint256 share = vaultToken.balanceOf(address(this));
    // withdraw
    _withdrawAndAssert(address(this), share);

    // expected withdraw amount
    uint256 expectedWithdraw = depositAmount * (MAX_BPS - withdrawalfeeBps) / MAX_BPS;

    // 1. full of deposit < full withdraw (must be deducted by withdrawal fee)
    assertLt(usdt.balanceOf(address(this)), depositAmount);
    // 2. withdraw 100%, should receive (100 - fee)%
    assertEq(usdt.balanceOf(address(this)), expectedWithdraw);
  }

  function testCorrectness_ManagementFee_InTheSameBlock_ShouldSkip() public {
    (,,,,,,,, uint40 _lastTimeCollectedBefore,,,) = vaultManager.vaultInfos(address(vaultToken));
    uint256 _timePassed = 1000;
    bytes[] memory _data = new bytes[](0);

    skip(_timePassed);

    // pendingManagementFee should call only once.
    vm.expectCall(address(vaultManager), abi.encodeWithSignature("pendingManagementFee(address)"), 1);
    // deposit
    _depositUSDTAndAssert(address(this), 1 ether);
    // manage
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), _data);
    // withdraw
    _withdrawAndAssert(address(this), 1 ether);

    (,,,,,,,, uint40 _lastTimeCollectedAfter,,,) = vaultManager.vaultInfos(address(vaultToken));
    assertEq(_lastTimeCollectedAfter, _lastTimeCollectedBefore + _timePassed);
  }

  function testCorrectness_ManagementFee_MustCollect_WhenDeposit() public {
    uint256 depositAmount = 100 ether;
    uint256 treasuryShareBefore = vaultToken.balanceOf(MANAGEMENT_FEE_TREASURY);
    uint32 managementFeePerSec = 2;
    uint256 timePassed = 100;

    // set management fee
    vm.prank(DEPLOYER);
    vaultManager.setManagementFeePerSec(address(vaultToken), managementFeePerSec);

    // deposit
    _depositUSDTAndAssert(address(this), depositAmount);

    uint256 vaultTotalSupply = vaultToken.totalSupply();

    // time pass
    skip(timePassed);

    // deposit
    _depositUSDTAndAssert(address(this), depositAmount);
    uint256 treasuryShareAfter = vaultToken.balanceOf(MANAGEMENT_FEE_TREASURY);

    uint256 expectedFee = timePassed * managementFeePerSec * vaultTotalSupply / 1e18;

    assertEq(treasuryShareAfter - treasuryShareBefore, expectedFee);
    assertGt(vaultToken.balanceOf(address(this)), depositAmount * 2);
  }

  function testCorrectness_ManagementFee_MustCollect_WhenManage() public {
    _depositUSDTAndAssert(address(this), 100 ether);
    uint256 treasuryShareBefore = vaultToken.balanceOf(MANAGEMENT_FEE_TREASURY);
    uint256 userShareBefore = vaultToken.balanceOf(address(this));
    uint32 managementFeePerSec = 2;
    uint256 timePassed = 100;

    // set management fee
    vm.prank(DEPLOYER);
    vaultManager.setManagementFeePerSec(address(vaultToken), managementFeePerSec);

    uint256 vaultTotalSupply = vaultToken.totalSupply();

    // time pass
    skip(timePassed);

    bytes[] memory _data = new bytes[](0);

    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), _data);

    uint256 expectedFee = timePassed * managementFeePerSec * vaultTotalSupply / 1e18;

    uint256 treasuryShareAfter = vaultToken.balanceOf(MANAGEMENT_FEE_TREASURY);
    uint256 userShareAfter = vaultToken.balanceOf(address(this));

    assertEq(treasuryShareAfter - treasuryShareBefore, expectedFee);
    assertEq(userShareAfter, userShareBefore);
  }

  function testCorrectness_ManagementFee_MustCollect_WhenWithdraw() public {
    uint256 depositAmount = 100 ether;
    uint256 treasuryShareBefore = vaultToken.balanceOf(MANAGEMENT_FEE_TREASURY);
    uint256 managementFeePerSec = 2;
    uint256 timePassed = 100;

    // set management fee
    vm.prank(DEPLOYER);
    vaultManager.setManagementFeePerSec(address(vaultToken), 2);

    // deposit
    _depositUSDTAndAssert(address(this), depositAmount);
    uint256 vaultTotalSupply = vaultToken.totalSupply();
    uint256 userShare = IERC20(vaultToken).balanceOf(address(this));
    uint256 withdrawAmount = userShare / 2;
    // time pass
    skip(100);
    uint256 expectedFee = timePassed * managementFeePerSec * vaultTotalSupply / 1e18;

    // withdraw
    _withdrawAndAssert(address(this), withdrawAmount);

    uint256 treasuryShareAfter = vaultToken.balanceOf(MANAGEMENT_FEE_TREASURY);

    assertEq(treasuryShareAfter - treasuryShareBefore, expectedFee);
    // actual withdraw amount < expected withdraw amount (fee deducted)
    assertLt(IERC20(usdt).balanceOf(address(this)), depositAmount / 2);
  }

  function testCorrectness_StableVault_Repurchase_WhenToken1Depegged() public {
    deal(address(usdt), address(this), 100 ether);
    usdt.approve(address(vaultManager), 100 ether);

    AutomatedVaultManager.TokenAmount[] memory deposits = new AutomatedVaultManager.TokenAmount[](1);
    deposits[0] = AutomatedVaultManager.TokenAmount({ token: address(usdt), amount: 100 ether });
    vaultManager.deposit(address(this), address(usdtBusdVaultToken), deposits, 0);

    // Current tick = 4
    // Borrow busd and open position
    deal(address(busd), address(moneyMarket), 100 ether);
    bytes[] memory executorData = new bytes[](2);
    executorData[0] = abi.encodeCall(PCSV3StableExecutor.borrow, (address(busd), 100 ether));
    executorData[1] = abi.encodeCall(PCSV3StableExecutor.openPosition, (2, 6, 100 ether, 100 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(usdtBusdVaultToken), executorData);

    // Swap to make BUSD depeg
    // Price after swap = 1.32
    deal(address(busd), address(this), 12917000 ether);
    busd.approve(address(pancakeV3Router), 12917000 ether);
    pancakeV3Router.exactInputSingle(
      IPancakeV3Router.ExactInputSingleParams({
        tokenIn: address(busd),
        tokenOut: address(usdt),
        fee: 100,
        recipient: address(this),
        amountIn: 12917000 ether,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      })
    );
    vm.prank(DEPLOYER);
    // Repurchasable when depeg more than 1%
    pancakeV3StableExecutor.setRepurchaseThreshold(LibSqrtPriceX96.encodeSqrtPriceX96(1.01 ether, 18, 18), 0);
    // Mock oracle price
    vm.mockCall(
      address(busdFeed), abi.encodeWithSignature("latestRoundData()"), abi.encode(0, 75757575, 0, block.timestamp, 0)
    );

    // Borrow usdt, swap and repay wbnb debt
    deal(address(usdt), address(moneyMarket), 1 ether);
    executorData = new bytes[](1);
    executorData[0] = abi.encodeCall(PCSV3StableExecutor.repurchase, (address(usdt), 1 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(usdtBusdVaultToken), executorData);
    // Assertions
    // - usdt debt increase
    (, uint256 usdtDebt) = bank.getVaultDebt(address(usdtBusdVaultToken), address(usdt));
    assertEq(usdtDebt, 1 ether);
    // - busd debt repaid
    (, uint256 busdDebt) = bank.getVaultDebt(address(usdtBusdVaultToken), address(busd));
    assertEq(busdDebt, 100 ether - 1318319302793630967); // 1318319302793630967 is usdt to busd swap output

    uint256 usdtBefore = usdt.balanceOf(address(this));
    uint256 busdBefore = busd.balanceOf(address(this));

    AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](2);
    minAmountOuts[0].token = address(usdt);
    minAmountOuts[0].amount = 0;
    minAmountOuts[1].token = address(busd);
    minAmountOuts[1].amount = 0;
    vaultManager.withdraw(address(usdtBusdVaultToken), usdtBusdVaultToken.balanceOf(address(this)), minAmountOuts);

    // Should only get busd since it is out of range
    assertEq(usdt.balanceOf(address(this)), usdtBefore);
    assertGt(busd.balanceOf(address(this)), busdBefore);
  }
}
