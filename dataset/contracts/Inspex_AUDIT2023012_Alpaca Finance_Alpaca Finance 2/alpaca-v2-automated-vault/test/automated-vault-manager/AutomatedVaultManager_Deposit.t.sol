// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";
import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";

contract AutomatedVaultManagerDepositTest is BaseAutomatedVaultUnitTest {
  constructor() BaseAutomatedVaultUnitTest() { }

  function testRevert_WhenDepositToUnopenedVault() public {
    AutomatedVaultManager.TokenAmount[] memory _depositParams = new AutomatedVaultManager.TokenAmount[](0);
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_VaultNotExist(address)", address(0)));
    vaultManager.deposit(address(this), address(0), _depositParams, 0);
  }

  function testRevert_WhenDepositIsEmergencyPaused() public {
    address _vaultToken = _openDefaultVault();
    address[] memory _vaultTokens = new address[](1);
    _vaultTokens[0] = _vaultToken;

    vm.prank(DEPLOYER);
    vaultManager.setIsDepositPaused(_vaultTokens, true);

    AutomatedVaultManager.TokenAmount[] memory _depositParams = new AutomatedVaultManager.TokenAmount[](0);
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_EmergencyPaused()"));
    vaultManager.deposit(address(this), address(_vaultToken), _depositParams, 0);
  }

  function testRevert_WhenDepositTokenThatIsNotAllowed() public {
    address vaultToken = _openDefaultVault();
    vm.prank(DEPLOYER);
    vaultManager.setAllowToken(address(vaultToken), address(mockToken0), false);
    deal(address(mockToken0), address(this), 1 ether);

    AutomatedVaultManager.TokenAmount[] memory params = new AutomatedVaultManager.TokenAmount[](1);
    params[0] = AutomatedVaultManager.TokenAmount({ token: address(mockToken0), amount: 1 ether });
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_TokenNotAllowed()"));
    vaultManager.deposit(address(this), address(vaultToken), params, 0);
  }

  function testRevert_WhenDepositBelowMinimumDepositSize() public {
    address vaultToken = _openVault(mockWorker, 100, DEFAULT_FEE_PER_SEC, DEFAULT_TOLERANCE_BPS, DEFAULT_MAX_LEVERAGE);
    uint256 equityAfter = 0.1 ether;

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: equityAfter,
      _debtAfter: 0
    });

    AutomatedVaultManager.TokenAmount[] memory params;
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_BelowMinimumDeposit()"));
    vaultManager.deposit(address(this), vaultToken, params, 0);
  }

  function testRevert_ReceiveSharesLessThanMinReceive() public {
    address vaultToken = _openDefaultVault();
    uint256 sharesOut = 1 ether;

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: sharesOut,
      _debtAfter: 0
    });

    AutomatedVaultManager.TokenAmount[] memory params;
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_TooLittleReceived()"));
    vaultManager.deposit(address(this), vaultToken, params, sharesOut + 1);
  }

  function testRevert_DepositExceedCapacity() public {
    address vaultToken = _openDefaultVault();
    vm.prank(DEPLOYER);
    vaultManager.setCapacity(vaultToken, 0);

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: 1,
      _debtAfter: 0
    });

    deal(address(mockToken0), address(this), 1 ether);

    AutomatedVaultManager.TokenAmount[] memory params = new AutomatedVaultManager.TokenAmount[](1);
    params[0].token = address(mockToken0);
    params[0].amount = 1 ether;
    mockToken0.approve(address(vaultManager), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_ExceedCapacity()"));
    vaultManager.deposit(address(this), vaultToken, params, 0);
  }

  function testCorrectness_WhenDeposit_TokensShouldBeTransferred_ShouldReceiveSharesEqualToEquityChanged() public {
    address vaultToken = _openDefaultVault();
    uint256 equityChanged = 1 ether;
    uint256 depositAmount = 1 ether;
    deal(address(mockToken0), address(this), depositAmount);
    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: equityChanged,
      _debtAfter: 0
    });

    uint256 balanceBefore = mockToken0.balanceOf(address(this));

    AutomatedVaultManager.TokenAmount[] memory params = new AutomatedVaultManager.TokenAmount[](1);
    params[0].token = address(mockToken0);
    params[0].amount = depositAmount;
    mockToken0.approve(address(vaultManager), depositAmount);
    vaultManager.deposit(address(this), vaultToken, params, 0);

    // Assertions
    // - user balance deducted by depositAmount
    // - user receive shares equal to equity change
    assertEq(balanceBefore - mockToken0.balanceOf(address(this)), depositAmount);
    assertEq(IERC20(vaultToken).balanceOf(address(this)), equityChanged);

    // Invariant: EXECUTOR_IN_SCOPE == address(0)
    assertEq(vaultManager.EXECUTOR_IN_SCOPE(), address(0));
  }

  function testCorrectness_WhenDeposit_ManagementFee_ShouldBeCollected() public {
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

    uint256 equityBefore = 1 ether;
    uint256 equityAfter = 2 ether;
    uint256 depositAmount = 1 ether;
    deal(address(mockToken0), address(this), depositAmount);
    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: equityBefore,
      _debtBefore: 0,
      _equityAfter: equityAfter,
      _debtAfter: 0
    });

    AutomatedVaultManager.TokenAmount[] memory params = new AutomatedVaultManager.TokenAmount[](1);
    params[0].token = address(mockToken0);
    params[0].amount = depositAmount;
    mockToken0.approve(address(vaultManager), depositAmount);
    vaultManager.deposit(address(this), vaultToken, params, 0);

    // state after
    (,,,,,,,, uint40 _lastTimeCollecteAfter,,,) = vaultManager.vaultInfos(address(vaultToken));

    // Assertions
    // 1. user's receive share amount = (deposit amount * (current share amount) / equity before deposit)
    // 2. management fee = (vault's total supply * time passed * fee/sec) / 1e18
    // 3. last collected time must be updated

    assertEq(
      IERC20(vaultToken).balanceOf(address(this)),
      depositAmount * (_vaultSupplyBefore + _expectedFee) / equityBefore,
      "User share amount"
    );
    assertEq(IERC20(vaultToken).balanceOf(managementFeeTreasury), _expectedFee, "Management fee treasury balance");
    assertGt(_lastTimeCollecteAfter, _lastTimeCollecteBefore, "Last collected time must be updated");
    assertEq(_lastTimeCollecteAfter, _time, "Update last collected time correctly");
  }
}
