// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { AVManagerV3Gateway, ERC20 } from "src/gateway/AVManagerV3Gateway.sol";
import { BaseAVManagerV3Gateway } from "test/av-manager-v3-gateway/BaseAVManagerV3Gateway.sol";
import { IAVManagerV3Gateway } from "src/interfaces/IAVManagerV3Gateway.sol";

contract AVManagerV3Gateway_DepositTest is BaseAVManagerV3Gateway {
  address vaultToken;

  constructor() BaseAVManagerV3Gateway() { }

  function setUp() public {
    vaultToken = _openDefaultVault();
  }

  function testCorrectness_DepositToken_withGateway_ShouldWork() external {
    uint256 _amount = 1 ether;
    deal(address(wbnb), USER_ALICE, _amount);

    uint256 _vaultTotalSupplyBefore = ERC20(vaultToken).totalSupply();
    uint256 _userShareBefore = ERC20(vaultToken).balanceOf(USER_ALICE);

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: _amount,
      _debtAfter: 0
    });

    vm.startPrank(USER_ALICE);
    wbnb.approve(address(avManagerV3Gateway), _amount);
    avManagerV3Gateway.deposit(vaultToken, address(wbnb), _amount, 0);
    vm.stopPrank();

    uint256 _vaultTotalSupplyAfter = ERC20(vaultToken).totalSupply();
    uint256 _userShareAfter = ERC20(vaultToken).balanceOf(USER_ALICE);

    // assume management fee = 0
    assertEq(_vaultTotalSupplyAfter - _vaultTotalSupplyBefore, _userShareAfter - _userShareBefore);

    // gateway must leave nothing
    assertEq(wbnb.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(usdt.balanceOf(address(avManagerV3Gateway)), 0);
  }

  function testCorrectness_DepositNative_withGateway_ShouldWork() external {
    uint256 _amount = 1 ether;
    deal(USER_ALICE, _amount);

    uint256 _vaultTotalSupplyBefore = ERC20(vaultToken).totalSupply();
    uint256 _userShareBefore = ERC20(vaultToken).balanceOf(USER_ALICE);

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: _amount,
      _debtAfter: 0
    });

    vm.startPrank(USER_ALICE);
    avManagerV3Gateway.depositETH{ value: _amount }(vaultToken, 0);
    vm.stopPrank();

    uint256 _vaultTotalSupplyAfter = ERC20(vaultToken).totalSupply();
    uint256 _userShareAfter = ERC20(vaultToken).balanceOf(USER_ALICE);

    assertEq(_vaultTotalSupplyAfter - _vaultTotalSupplyBefore, _userShareAfter - _userShareBefore);

    assertEq(address(avManagerV3Gateway).balance, 0);
    assertEq(wbnb.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(usdt.balanceOf(address(avManagerV3Gateway)), 0);
  }

  function testRevert_MinReceive_ShouldForward_ToAVManager() external {
    uint256 _amount = 1 ether;
    deal(USER_ALICE, _amount);

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: _amount,
      _debtAfter: 0
    });

    vm.startPrank(USER_ALICE);
    vm.expectRevert(abi.encodeWithSelector(AutomatedVaultManager.AutomatedVaultManager_TooLittleReceived.selector));
    avManagerV3Gateway.depositETH{ value: _amount }(vaultToken, _amount + 1 ether);
    vm.stopPrank();
  }

  function testRevert_Deposit_InvalidInput() external {
    // erc20 token amount = 0
    vm.expectRevert(abi.encodeWithSelector(IAVManagerV3Gateway.AVManagerV3Gateway_InvalidInput.selector));
    avManagerV3Gateway.deposit(address(vaultToken), address(wbnb), 0, 0);

    // native
    vm.expectRevert(abi.encodeWithSelector(IAVManagerV3Gateway.AVManagerV3Gateway_InvalidInput.selector));
    avManagerV3Gateway.depositETH{ value: 0 }(address(vaultToken), 0);
  }
}
