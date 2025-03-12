// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { AVManagerV3Gateway, ERC20 } from "src/gateway/AVManagerV3Gateway.sol";
import { BaseAVManagerV3Gateway, console } from "test/av-manager-v3-gateway/BaseAVManagerV3Gateway.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IAVManagerV3Gateway } from "src/interfaces/IAVManagerV3Gateway.sol";
import { MockPancakeV3Worker } from "test/mocks/MockPancakeV3Worker.sol";
import { IERC20 } from "src/interfaces/IERC20.sol";

contract AVManagerV3GatewayWithdrawTest is BaseAVManagerV3Gateway {
  address vaultToken;
  address _pool;
  IERC20 _token0;
  IERC20 _token1;
  uint256 _amountToWithdraw;

  constructor() BaseAVManagerV3Gateway() { }

  function setUp() public {
    vaultToken = _openDefaultVault();

    _amountToWithdraw = 1 ether;

    // This pool token0 is usdt, token1 is wbnb
    _token0 = usdt;
    _token1 = wbnb;
    _pool = address(pancakeV3USDTWBNBPool);

    // deal vault share 1 ether
    deal(address(vaultToken), USER_ALICE, 1 ether);

    // mock worker call
    vm.mockCall(address(mockWorker), abi.encodeWithSignature("token0()"), abi.encode(address(_token0)));
    vm.mockCall(address(mockWorker), abi.encodeWithSignature("token1()"), abi.encode(address(_token1)));
    vm.mockCall(address(mockWorker), abi.encodeWithSignature("pool()"), abi.encode(_pool));
  }

  function testCorrectness_WithdrawConvertAll_To_Token0_ShouldWork() external {
    bool _zeroForOne = false;
    uint256 _userVaultShareBefore = ERC20(vaultToken).balanceOf(USER_ALICE);

    // deal token to vault manager
    AutomatedVaultManager.TokenAmount[] memory _withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    _withdrawResults[0].token = address(_token0);
    _withdrawResults[0].amount = 1 ether;
    _withdrawResults[1].token = address(_token1);
    _withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(_withdrawResults);
    deal(_withdrawResults[0].token, address(vaultManager), _withdrawResults[0].amount);
    deal(_withdrawResults[1].token, address(vaultManager), _withdrawResults[1].amount);

    // withdraw
    vm.startPrank(USER_ALICE);
    ERC20(vaultToken).approve(address(avManagerV3Gateway), _amountToWithdraw);
    uint256 _amountOut = avManagerV3Gateway.withdrawConvertAll(vaultToken, _amountToWithdraw, _zeroForOne, 0);
    vm.stopPrank();

    uint256 _userVaultShareAfter = ERC20(vaultToken).balanceOf(USER_ALICE);

    // user balance
    // token0 is usdt
    assertEq(_token0.balanceOf(USER_ALICE), _amountOut);
    // token1 is wbnb, we have to check bnb native
    assertEq(USER_ALICE.balance, 0);

    // user vault share
    assertEq(_userVaultShareAfter, _userVaultShareBefore - _amountToWithdraw);

    // gateway should have nothing
    assertEq(_token0.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(_token1.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(address(avManagerV3Gateway).balance, 0);
  }

  function testCorrectness_WithdrawConvertAll_To_Token1_ShouldWork() external {
    bool _zeroForOne = true;
    uint256 _userVaultShareBefore = ERC20(vaultToken).balanceOf(USER_ALICE);

    // deal token to vault manager
    AutomatedVaultManager.TokenAmount[] memory _withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    _withdrawResults[0].token = address(_token0);
    _withdrawResults[0].amount = 1 ether;
    _withdrawResults[1].token = address(_token1);
    _withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(_withdrawResults);
    deal(_withdrawResults[0].token, address(vaultManager), _withdrawResults[0].amount);
    deal(_withdrawResults[1].token, address(vaultManager), _withdrawResults[1].amount);

    // withdraw
    vm.startPrank(USER_ALICE);
    ERC20(vaultToken).approve(address(avManagerV3Gateway), _amountToWithdraw);
    uint256 _amountOut = avManagerV3Gateway.withdrawConvertAll(vaultToken, _amountToWithdraw, _zeroForOne, 0);
    vm.stopPrank();

    uint256 _userVaultShareAfter = ERC20(vaultToken).balanceOf(USER_ALICE);

    // user balance
    // token0 is usdt
    assertEq(_token0.balanceOf(USER_ALICE), 0);
    // token1 is wbnb, we have to check bnb native
    assertEq(USER_ALICE.balance, _amountOut);

    // user vault share
    assertEq(_userVaultShareAfter, _userVaultShareBefore - _amountToWithdraw);

    // gateway should have nothing
    assertEq(_token0.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(_token1.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(address(avManagerV3Gateway).balance, 0);
  }

  function testCorrectness_WithdrawMinimize_ShouldWork() external {
    // prepare
    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(wbnb);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(usdt);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    // withdraw
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts = new AutomatedVaultManager.TokenAmount[](2);
    _minAmountOuts[0].token = address(wbnb);
    _minAmountOuts[0].amount = 0;
    _minAmountOuts[1].token = address(usdt);
    _minAmountOuts[1].amount = 0;
    vm.startPrank(USER_ALICE);
    ERC20(vaultToken).approve(address(avManagerV3Gateway), _amountToWithdraw);
    avManagerV3Gateway.withdrawMinimize(vaultToken, _amountToWithdraw, _minAmountOuts);
    vm.stopPrank();

    // Expect
    // native bnb = 1 ether
    // wbnb = 0 (should not have token here)
    // usdt = 1 ether
    assertEq(USER_ALICE.balance, 1 ether);
    assertEq(wbnb.balanceOf(USER_ALICE), 0);
    assertEq(usdt.balanceOf(USER_ALICE), 2 ether);
  }

  function testRevert_WhenWithdrawAmountOut_IsLessThan_MinReceive() external {
    // withdrawMinimize was tested by from AutomatedVaultManager.withdraw

    // withdrawConvertAll
    // deal token to vault manager
    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(_token0);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(_token1);
    withdrawResults[1].amount = 1 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    // withdraw
    vm.startPrank(USER_ALICE);
    ERC20(vaultToken).approve(address(avManagerV3Gateway), _amountToWithdraw);
    vm.expectRevert(abi.encodeWithSelector(IAVManagerV3Gateway.AVManagerV3Gateway_TooLittleReceived.selector));
    avManagerV3Gateway.withdrawConvertAll(vaultToken, _amountToWithdraw, false, 400 ether);
    vm.stopPrank();
  }
}
