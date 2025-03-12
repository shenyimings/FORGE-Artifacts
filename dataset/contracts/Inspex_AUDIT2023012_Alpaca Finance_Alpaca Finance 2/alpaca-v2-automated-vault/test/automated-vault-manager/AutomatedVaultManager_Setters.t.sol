// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

contract AutomatedVaultManagerSettersTest is BaseAutomatedVaultUnitTest {
  address vaultToken;

  constructor() BaseAutomatedVaultUnitTest() {
    vaultToken = _openDefaultVault();
  }

  function testRevert_SetVaultManager_NonOwnerIsCaller() public {
    address _vaultToken = makeAddr("vaultToken");
    address _manager = makeAddr("manager");

    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setVaultManager(_vaultToken, _manager, true);
  }
}

contract AutomatedVaultManagerSetAllowTokenTest is AutomatedVaultManagerSettersTest {
  function testRevert_SetAllowToken_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setAllowToken(vaultToken, address(1234), true);
  }

  function testRevert_SetAllowToken_VaultNotOpened() public {
    vm.prank(DEPLOYER);
    vm.expectRevert(
      abi.encodeWithSelector(AutomatedVaultManager.AutomatedVaultManager_VaultNotExist.selector, address(1234))
    );
    vaultManager.setAllowToken(address(1234), address(1234), true);
  }
}

contract AutomatedVaultManagerSetVaultTokenImplementationTest is AutomatedVaultManagerSettersTest {
  function testRevert_SetVaultTokenImplementation_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setVaultTokenImplementation(address(1234));
  }

  function testCorrectness_SetVaultTokenImplementation() public {
    address implementation = address(1234);
    vm.prank(DEPLOYER);
    vaultManager.setVaultTokenImplementation(implementation);
    assertEq(vaultManager.vaultTokenImplementation(), implementation);
  }
}

contract AutomatedVaultManagerSetToleranceBpsTest is AutomatedVaultManagerSettersTest {
  function testRevert_SetToleranceBps_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setToleranceBps(vaultToken, 1);
  }

  function testRevert_SetToleranceBps_InvalidValue() public {
    vm.startPrank(DEPLOYER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setToleranceBps(vaultToken, 1);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setToleranceBps(vaultToken, 10001);
  }

  function testCorrectness_SetToleranceBps() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setToleranceBps(vaultToken, 9501);
    (,,,,,,,,,, uint16 toleranceBps,) = vaultManager.vaultInfos(vaultToken);
    assertEq(toleranceBps, 9501);
    vaultManager.setToleranceBps(vaultToken, 9900);
    (,,,,,,,,,, toleranceBps,) = vaultManager.vaultInfos(vaultToken);
    assertEq(toleranceBps, 9900);
    vaultManager.setToleranceBps(vaultToken, 10000);
    (,,,,,,,,,, toleranceBps,) = vaultManager.vaultInfos(vaultToken);
    assertEq(toleranceBps, 10000);
  }
}

contract AutomatedVaultManagerSetMaxLeverageTest is AutomatedVaultManagerSettersTest {
  function testRevert_SetMaxLeverage_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setMaxLeverage(vaultToken, 1);
  }

  function testRevert_SetMaxLeverage_InvalidValue() public {
    vm.startPrank(DEPLOYER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setMaxLeverage(vaultToken, 0);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setMaxLeverage(vaultToken, 11);
  }

  function testCorrectness_SetMaxLeverage() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setMaxLeverage(vaultToken, 1);
    (,,,,,,,,,,, uint8 maxLeverage) = vaultManager.vaultInfos(vaultToken);
    assertEq(maxLeverage, 1);
    vaultManager.setMaxLeverage(vaultToken, 5);
    (,,,,,,,,,,, maxLeverage) = vaultManager.vaultInfos(vaultToken);
    assertEq(maxLeverage, 5);
    vaultManager.setMaxLeverage(vaultToken, 10);
    (,,,,,,,,,,, maxLeverage) = vaultManager.vaultInfos(vaultToken);
    assertEq(maxLeverage, 10);
  }
}

contract AutomatedVaultManagerSetMinimumDepositTest is AutomatedVaultManagerSettersTest {
  function testRevert_SetMinimumDeposit_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setMinimumDeposit(vaultToken, 1);
  }

  function testRevert_SetMinimumDeposit_InvalidValue() public {
    vm.startPrank(DEPLOYER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setMinimumDeposit(vaultToken, 0);
  }

  function testCorrectness_SetMinimumDeposit() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setMinimumDeposit(vaultToken, 1);
    (, uint32 compressedMinimumDeposit,,,,,,,,,,) = vaultManager.vaultInfos(vaultToken);
    assertEq(compressedMinimumDeposit, 1);
  }
}

contract AutomatedVaultManagerSetFeePerSecTest is AutomatedVaultManagerSettersTest {
  function testRevert_SetManagementFeePerSec_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setManagementFeePerSec(vaultToken, 1);
  }

  function testCorrectness_SetManagementFeePerSec() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setManagementFeePerSec(vaultToken, 10);
    (,,,,,,, uint32 managementFeePerSec,,,,) = vaultManager.vaultInfos(vaultToken);
    assertEq(managementFeePerSec, 10);
    vaultManager.setManagementFeePerSec(vaultToken, 12);
    (,,,,,,, managementFeePerSec,,,,) = vaultManager.vaultInfos(vaultToken);
    assertEq(managementFeePerSec, 12);
  }
}

contract AutomatedVaultManagerSetCapacityTest is AutomatedVaultManagerSettersTest {
  function testRevert_SetCapacity_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setCapacity(vaultToken, 1);
  }

  function testCorrectness_SetCapacity() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setCapacity(vaultToken, 10);
    (,, uint32 compressedCapacity,,,,,,,,,) = vaultManager.vaultInfos(vaultToken);
    assertEq(compressedCapacity, 10);
    vaultManager.setCapacity(vaultToken, 0);
    (,, compressedCapacity,,,,,,,,,) = vaultManager.vaultInfos(vaultToken);
    assertEq(compressedCapacity, 0);
  }
}

contract AutomatedVaultManagerSetIsPausedTest is AutomatedVaultManagerSettersTest {
  // Deposit paused

  function testRevert_SetIsDepositPaused_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setIsDepositPaused(new address[](1), true);
  }

  function _assertDepositPaused(address _vaultToken, bool _expected) internal {
    (,,, bool isDepositPaused,,,,,,,,) = vaultManager.vaultInfos(_vaultToken);
    assertEq(isDepositPaused, _expected);
  }

  function testCorrectness_SetIsDepositPaused_MultipleVaults() public {
    address _vaultToken1 = makeAddr("vaultToken1");
    address _vaultToken2 = makeAddr("vaultToken2");
    address[] memory _vaultTokens = new address[](2);
    _vaultTokens[0] = _vaultToken1;
    _vaultTokens[1] = _vaultToken2;

    // unset vaults should be false by default
    _assertDepositPaused(_vaultToken1, false);
    _assertDepositPaused(_vaultToken2, false);

    vm.startPrank(DEPLOYER);
    // should be true
    vaultManager.setIsDepositPaused(_vaultTokens, true);
    _assertDepositPaused(_vaultToken1, true);
    _assertDepositPaused(_vaultToken2, true);

    // should be false
    vaultManager.setIsDepositPaused(_vaultTokens, false);
    _assertDepositPaused(_vaultToken1, false);
    _assertDepositPaused(_vaultToken2, false);
    vm.stopPrank();
  }

  // Withdraw paused

  function testRevert_SetIsWithdrawPaused_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setIsWithdrawPaused(new address[](1), true);
  }

  function _assertWithdrawPaused(address _vaultToken, bool _expected) internal {
    (,,,,, bool isWithdrawPaused,,,,,,) = vaultManager.vaultInfos(_vaultToken);
    assertEq(isWithdrawPaused, _expected);
  }

  function testCorrectness_SetIsWithdrawPaused_MultipleVaults() public {
    address _vaultToken1 = makeAddr("vaultToken1");
    address _vaultToken2 = makeAddr("vaultToken2");
    address[] memory _vaultTokens = new address[](2);
    _vaultTokens[0] = _vaultToken1;
    _vaultTokens[1] = _vaultToken2;

    // unset vaults should be false by default
    _assertWithdrawPaused(_vaultToken1, false);
    _assertWithdrawPaused(_vaultToken2, false);

    vm.startPrank(DEPLOYER);
    // should be true
    vaultManager.setIsWithdrawPaused(_vaultTokens, true);
    _assertWithdrawPaused(_vaultToken1, true);
    _assertWithdrawPaused(_vaultToken2, true);

    // should be false
    vaultManager.setIsWithdrawPaused(_vaultTokens, false);
    _assertWithdrawPaused(_vaultToken1, false);
    _assertWithdrawPaused(_vaultToken2, false);
    vm.stopPrank();
  }
}
