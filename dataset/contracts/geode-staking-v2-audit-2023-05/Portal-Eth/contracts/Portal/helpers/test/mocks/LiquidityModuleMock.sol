// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {LiquidityModule} from "../../../modules/LiquidityModule/LiquidityModule.sol";
import {LiquidityModuleLib as LML} from "../../../modules/LiquidityModule/libs/LiquidityModuleLib.sol";
import {AmplificationLib as AL} from "../../../modules/LiquidityModule/libs/AmplificationLib.sol";

contract LiquidityModuleMock is LiquidityModule {
  using LML for LML.Swap;
  using AL for LML.Swap;

  event return$swap(uint256 ret0);

  event return$addLiquidity(uint256 ret0);

  event return$removeLiquidity(uint256[2] ret0);

  event return$removeLiquidityOneToken(uint256 ret0);

  event return$removeLiquidityImbalance(uint256 ret0);

  function initialize(
    address _gETH_position,
    address _lpToken_referance,
    uint256 _pooledTokenId,
    uint256 _initialA,
    uint256 _swapFee,
    string calldata _poolName
  ) external initializer {
    __LiquidityModule_init(
      _gETH_position,
      _lpToken_referance,
      _pooledTokenId,
      _initialA,
      _swapFee,
      _poolName
    );
  }

  function pause() external virtual override {
    _pause();
  }

  function unpause() external virtual override {
    _unpause();
  }

  /**
   * @custom:section                           ** FOR RETURN STATEMENTS **
   */

  function swap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline
  ) public payable virtual override returns (uint256 ret0) {
    (ret0) = super.swap(tokenIndexFrom, tokenIndexTo, dx, minDy, deadline);
    emit return$swap(ret0);
  }

  function addLiquidity(
    uint256[2] calldata amounts,
    uint256 minToMint,
    uint256 deadline
  ) public payable override returns (uint256 ret0) {
    (ret0) = super.addLiquidity(amounts, minToMint, deadline);
    emit return$addLiquidity(ret0);
  }

  function removeLiquidity(
    uint256 amount,
    uint256[2] calldata minAmounts,
    uint256 deadline
  ) public override returns (uint256[2] memory ret0) {
    (ret0) = super.removeLiquidity(amount, minAmounts, deadline);
    emit return$removeLiquidity(ret0);
  }

  function removeLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex,
    uint256 minAmount,
    uint256 deadline
  ) public override returns (uint256 ret0) {
    (ret0) = super.removeLiquidityOneToken(tokenAmount, tokenIndex, minAmount, deadline);
    emit return$removeLiquidityOneToken(ret0);
  }

  function removeLiquidityImbalance(
    uint256[2] calldata amounts,
    uint256 maxBurnAmount,
    uint256 deadline
  ) public override returns (uint256 ret0) {
    (ret0) = super.removeLiquidityImbalance(amounts, maxBurnAmount, deadline);
    emit return$removeLiquidityImbalance(ret0);
  }

  /**
   * @custom:section                           ** LIQUIDITY POOL ADMIN **
   */

  function setSwapFee(uint256 newSwapFee) public virtual override {
    LIQUIDITY.setSwapFee(newSwapFee);
  }

  function setAdminFee(uint256 newAdminFee) public virtual override {
    LIQUIDITY.setAdminFee(newAdminFee);
  }

  function withdrawAdminFees(address receiver) public virtual override {
    LIQUIDITY.withdrawAdminFees(receiver);
  }

  function rampA(uint256 futureA, uint256 futureTime) public virtual override {
    LIQUIDITY.rampA(futureA, futureTime);
  }

  function stopRampA() public virtual override {
    LIQUIDITY.stopRampA();
  }

  /**
   * @notice fallback functions
   */

  receive() external payable {}
}
