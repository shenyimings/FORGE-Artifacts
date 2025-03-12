// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

contract AutomatedVaultManagerWithdrawTest is BaseAutomatedVaultUnitTest {
  constructor() BaseAutomatedVaultUnitTest() { }

  function testRevert_WhenWithdrawFromUnopenedVault() public {
    AutomatedVaultManager.TokenAmount[] memory minAmountOuts;
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_VaultNotExist(address)", address(0)));
    vaultManager.withdraw(address(0), 0, minAmountOuts);
  }

  function testRevert_WhenWithdrawIsEmergencyPaused() public {
    address _vaultToken = _openDefaultVault();
    address[] memory _vaultTokens = new address[](1);
    _vaultTokens[0] = _vaultToken;

    vm.prank(DEPLOYER);
    vaultManager.setIsWithdrawPaused(_vaultTokens, true);

    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts;
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_EmergencyPaused()"));
    vaultManager.withdraw(_vaultToken, 1, _minAmountOuts);
  }

  function testRevert_WhenWithdrawSharesExceedBalance() public {
    address vaultToken = _openDefaultVault();

    AutomatedVaultManager.TokenAmount[] memory minAmountOuts;
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_WithdrawExceedBalance()"));
    vaultManager.withdraw(vaultToken, 1, minAmountOuts);
  }

  // function testRevert_WhenWithdrawCauseTooMuchEquityLoss() public {
  //   // withdraw 10% of shares
  //   uint256 sharesToWithdraw = 0.1 ether;
  //   uint256 totalShares = 1 ether;

  //   address vaultToken = _openDefaultVault();
  //   deal(vaultToken, address(this), totalShares, true);
  //   mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
  //     _equityBefore: 100,
  //     _debtBefore: 0,
  //     _equityAfter: 50,
  //     _debtAfter: 0
  //   });

  //   // Calculation
  //   // equity before = 100, after = 50 => equityChanged = 50
  //   // maxEquityChange = withdrawPct * equityBefore = 10% * 100 = 10
  //   // should revert due to equityChanged > maxEquityChange

  //   AutomatedVaultManager.TokenAmount[] memory minAmountOuts;
  //   vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_TooMuchEquityLoss()"));
  //   vaultManager.withdraw(vaultToken, sharesToWithdraw, minAmountOuts);
  // }

  function testRevert_WhenTokenAmountExceedSlippage() public {
    uint256 sharesToWithdraw = 1 ether;

    address vaultToken = _openDefaultVault();
    deal(vaultToken, address(this), sharesToWithdraw, true);

    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(mockToken0);
    withdrawResults[0].amount = 0.9 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);

    AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](2);
    minAmountOuts[0].token = address(mockToken0);
    minAmountOuts[0].amount = 1 ether;
    // should revert: amount = 1 ether, actualAmount = 0.9 ether
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_TooLittleReceived()"));
    vaultManager.withdraw(vaultToken, sharesToWithdraw, minAmountOuts);
  }

  function testCorrectness_WhenWithdraw_ShouldBurnShares_ShouldTransferTokenToUser() public {
    uint256 sharesToWithdraw = 1 ether;

    address vaultToken = _openDefaultVault();
    deal(vaultToken, address(this), sharesToWithdraw, true);

    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(mockToken0);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(mockToken1);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    uint256 sharesBefore = IERC20(vaultToken).balanceOf(address(this));
    uint256 token0Before = mockToken0.balanceOf(address(this));
    uint256 token1Before = mockToken1.balanceOf(address(this));

    AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](2);
    minAmountOuts[0].token = address(mockToken0);
    minAmountOuts[0].amount = 0;
    minAmountOuts[1].token = address(mockToken1);
    minAmountOuts[1].amount = 0;
    vaultManager.withdraw(vaultToken, sharesToWithdraw, minAmountOuts);

    // Assertions
    // - user shares burned by sharesToWithdraw
    // - user receive tokens sent from executor
    assertEq(sharesBefore - IERC20(vaultToken).balanceOf(address(this)), sharesToWithdraw);
    assertEq(mockToken0.balanceOf(address(this)) - token0Before, withdrawResults[0].amount);
    assertEq(mockToken1.balanceOf(address(this)) - token1Before, withdrawResults[1].amount);

    // Invariant: EXECUTOR_IN_SCOPE == address(0)
    assertEq(vaultManager.EXECUTOR_IN_SCOPE(), address(0));
  }

  function testCorrectness_WhenWithdraw_ManagementFee_ShouldBeCollected() public {
    uint256 sharesToWithdraw = 1 ether;

    address vaultToken = _openDefaultVault();
    deal(vaultToken, address(this), sharesToWithdraw, true);

    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(mockToken0);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(mockToken1);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    // state before
    uint256 _vaultSupplyBefore = IERC20(vaultToken).totalSupply();
    (,,,,,,,, uint40 _lastTimeCollecteBefore,,,) = vaultManager.vaultInfos(address(vaultToken));

    uint256 _timePassed = 100;
    uint32 _managementFeePerSec = 1;
    uint256 _expectedFee = (_vaultSupplyBefore * _timePassed * _managementFeePerSec) / 1e18;

    // set fee
    vm.startPrank(DEPLOYER);
    vaultManager.setManagementFeePerSec(vaultToken, _managementFeePerSec);
    vm.stopPrank();
    // warp
    uint256 _time = block.timestamp + _timePassed;
    vm.warp(_time);

    AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](2);
    minAmountOuts[0].token = address(mockToken0);
    minAmountOuts[0].amount = 0;
    minAmountOuts[1].token = address(mockToken1);
    minAmountOuts[1].amount = 0;
    vaultManager.withdraw(vaultToken, sharesToWithdraw, minAmountOuts);

    // state after
    (,,,,,,,, uint40 _lastTimeCollecteAfter,,,) = vaultManager.vaultInfos(address(vaultToken));

    // Assertions
    // - management fee is minted
    // - [Cannot test] user share must be smaller since some the shares is increased

    assertEq(IERC20(vaultToken).balanceOf(managementFeeTreasury), _expectedFee, "Management fee treasury balance");
    assertGt(_lastTimeCollecteAfter, _lastTimeCollecteBefore, "Last collected time must be updated");
    assertEq(_lastTimeCollecteAfter, _time, "Update last collected time correctly");
  }

  function testCorrectness_WhenWithdraw_WithdrawalFee_ShouldBeCollected() public {
    uint256 sharesToWithdraw = 1 ether;
    uint16 withdrawalFeeBps = 100;

    address vaultToken = _openDefaultVault();
    deal(vaultToken, address(this), sharesToWithdraw, true);

    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(mockToken0);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(mockToken1);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    // set fee
    vm.startPrank(DEPLOYER);
    vaultManager.setWithdrawalFeeBps(vaultToken, withdrawalFeeBps);
    vm.stopPrank();

    AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](2);
    minAmountOuts[0].token = address(mockToken0);
    minAmountOuts[0].amount = 0;
    minAmountOuts[1].token = address(mockToken1);
    minAmountOuts[1].amount = 0;
    vaultManager.withdraw(vaultToken, sharesToWithdraw, minAmountOuts);

    // expect withdrawal fee = (withdraw amount * fee bps) / max bps
    uint256 expectWithdrawalFee = (sharesToWithdraw * withdrawalFeeBps) / 10000;
    // withdrawal fee must be minted to treasury
    assertEq(IERC20(vaultToken).balanceOf(WITHDRAWAL_FEE_TREASURY), expectWithdrawalFee);
  }

  function testRevert_InvalidMinAmount_ShouldRevert() external {
    uint256 sharesToWithdraw = 1 ether;

    address vaultToken = _openDefaultVault();
    deal(vaultToken, address(this), sharesToWithdraw, true);

    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(mockToken0);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(mockToken1);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    // Case 1: Invalid min amount out length
    AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](1);
    minAmountOuts[0].token = address(mockToken0);
    minAmountOuts[0].amount = 0;
    vm.expectRevert(abi.encodeWithSelector(AutomatedVaultManager.AutomatedVaultManager_InvalidMinAmountOut.selector));
    vaultManager.withdraw(vaultToken, sharesToWithdraw, minAmountOuts);

    // Case 1: Invalid min amount out address
    minAmountOuts = new AutomatedVaultManager.TokenAmount[](2);
    minAmountOuts[0].token = address(0);
    minAmountOuts[0].amount = 0;
    minAmountOuts[1].token = address(0);
    minAmountOuts[1].amount = 0;
    vm.expectRevert(abi.encodeWithSelector(AutomatedVaultManager.AutomatedVaultManager_TokenMismatch.selector));
    vaultManager.withdraw(vaultToken, sharesToWithdraw, minAmountOuts);
  }

  function testCorrectness_whenMinAmountOutLength_IsMoreThanWithdrawResultLength_ShouldWork() external {
    uint256 sharesToWithdraw = 1 ether;

    address vaultToken = _openDefaultVault();
    deal(vaultToken, address(this), sharesToWithdraw, true);

    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(mockToken0);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(mockToken1);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    uint256 sharesBefore = IERC20(vaultToken).balanceOf(address(this));
    uint256 token0Before = mockToken0.balanceOf(address(this));
    uint256 token1Before = mockToken1.balanceOf(address(this));

    AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](3);
    minAmountOuts[0].token = address(mockToken0);
    minAmountOuts[0].amount = 0;
    minAmountOuts[1].token = address(mockToken1);
    minAmountOuts[1].amount = 0;
    vaultManager.withdraw(vaultToken, sharesToWithdraw, minAmountOuts);

    // Assertions
    // - user shares burned by sharesToWithdraw
    // - user receive tokens sent from executor
    assertEq(sharesBefore - IERC20(vaultToken).balanceOf(address(this)), sharesToWithdraw);
    assertEq(mockToken0.balanceOf(address(this)) - token0Before, withdrawResults[0].amount);
    assertEq(mockToken1.balanceOf(address(this)) - token1Before, withdrawResults[1].amount);
  }
}
