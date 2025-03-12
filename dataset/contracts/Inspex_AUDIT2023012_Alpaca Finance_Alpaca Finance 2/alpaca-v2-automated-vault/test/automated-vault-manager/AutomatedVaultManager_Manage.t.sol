// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

contract AutomatedVaultManagerManageTest is BaseAutomatedVaultUnitTest {
  constructor() BaseAutomatedVaultUnitTest() { }

  function testRevert_WhenNonManagerCallManage_ShouldRevert() external {
    address vaultToken = _openDefaultVault();
    vm.prank(address(1234));
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_Unauthorized.selector);
    vaultManager.manage(address(vaultToken), new bytes[](1));
  }

  function testFuzzRevert_WhenManageCauseTooMuchEquityLoss(uint16 tolerance, uint256 equityBefore, uint256 equityAfter)
    public
  {
    tolerance = uint16(bound(tolerance, 9501, 10000));
    equityBefore = bound(equityBefore, 1, 1e30);
    equityAfter = bound(equityAfter, 0, equityBefore * tolerance / 10000);
    if (equityAfter > 0) equityAfter -= 1; // prevent equal case

    address vaultToken =
      _openVault(mockWorker, DEFAULT_MINIMUM_DEPOSIT, DEFAULT_FEE_PER_SEC, tolerance, DEFAULT_MAX_LEVERAGE);

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: equityBefore,
      _debtBefore: 0,
      _equityAfter: equityAfter,
      _debtAfter: 0
    });

    vm.prank(MANAGER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_TooMuchEquityLoss.selector);
    vaultManager.manage(address(vaultToken), new bytes[](0));
  }

  function testRevert_WhenManageCauseTooMuchLeverage() public {
    // max 10x leverage
    address vaultToken = _openVault(mockWorker, DEFAULT_MINIMUM_DEPOSIT, DEFAULT_FEE_PER_SEC, DEFAULT_TOLERANCE_BPS, 10);

    // 10x leverage with 100 equity allow up to 900 debt
    // 901 should revert
    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 100,
      _debtBefore: 0,
      _equityAfter: 100,
      _debtAfter: 901
    });

    vm.prank(MANAGER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_TooMuchLeverage.selector);
    vaultManager.manage(address(vaultToken), new bytes[](0));
  }

  function testCorrectness_ManagingVaultResultInHealthyState_ShouldWork() external {
    address vaultToken = _openDefaultVault();

    vm.expectCall(address(mockVaultOracleAndExecutor), abi.encodeWithSignature("multicall(bytes[])"), 1);
    vm.expectCall(address(mockVaultOracleAndExecutor), abi.encodeWithSignature("sweepToWorker()"), 1);

    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), new bytes[](0));

    // Invariant: EXECUTOR_IN_SCOPE == address(0)
    assertEq(vaultManager.EXECUTOR_IN_SCOPE(), address(0));
  }

  function testCorrectness_WhenManage_ManagementFee_ShouldBeCollected() external {
    address vaultToken = _openDefaultVault();

    vm.prank(address(vaultManager));
    AutomatedVaultERC20(vaultToken).mint(address(1), 1 ether);
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

    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), new bytes[](0));

    // state after
    (,,,,,,,, uint40 _lastTimeCollecteAfter,,,) = vaultManager.vaultInfos(address(vaultToken));

    assertEq(IERC20(vaultToken).balanceOf(managementFeeTreasury), _expectedFee, "Management fee treasury balance");
    assertGt(_lastTimeCollecteAfter, _lastTimeCollecteBefore, "Last collected time must be updated");
    assertEq(_lastTimeCollecteAfter, _time, "Update last collected time correctly");
  }
}
