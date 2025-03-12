// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface BasePoolInterface {
  enum MinMax {
    MIN,
    MAX
  }

  function additionalAum() external view returns (uint256);

  function approvedPlugins(address, address) external view returns (bool);

  function config() external view returns (address);

  function decreasePosition(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    uint8 exposure,
    address receiver
  ) external returns (uint256);

  function discountedAum() external view returns (uint256);

  function feeReserveOf(address) external view returns (uint256);

  function getAddLiquidityFeeBps(address token, uint256 deltaValue)
    external
    view
    returns (uint256);

  function getAumE18(bool isUseMaxPrice) external view returns (uint256);

  function getTargetValue(address token) external view returns (uint256);

  // function getPosition(
  //   address primaryAccount,
  //   uint256 subAccountId,
  //   address collateralToken,
  //   address indexToken,
  //   uint8 exposure
  // ) external view returns (Pool.GetPositionReturnVars memory);

  // function getPosition(
  //   address account,
  //   address collateralToken,
  //   address indexToken,
  //   uint8 exposure
  // ) external view returns (Pool.GetPositionReturnVars memory);

  function getPositionDelta(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint8 exposure
  ) external view returns (bool, uint256);

  function getPositionId(
    address account,
    address collateralToken,
    address indexToken,
    uint8 exposure
  ) external pure returns (bytes32);

  function getSubAccount(address primary, uint256 subAccountId)
    external
    pure
    returns (address);

  function guaranteedUsdOf(address) external view returns (uint256);

  function increasePosition(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 sizeDelta,
    uint8 exposure
  ) external;

  function lastAddLiquidityAtOf(address) external view returns (uint256);

  function lastFundingTimeOf(address) external view returns (uint256);

  function liquidate(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint8 exposure,
    address to
  ) external;

  function liquidityOf(address) external view returns (uint256);

  function oracle() external view returns (address);

  function owner() external view returns (address);

  function plp() external view returns (address);

  function poolMath() external view returns (address);

  function positions(bytes32)
    external
    view
    returns (
      address primaryAccount,
      uint256 size,
      uint256 collateral,
      uint256 averagePrice,
      uint256 entryBorrowingRate,
      uint256 reserveAmount,
      int256 realizedPnl,
      uint256 lastIncreasedTime
    );

  function removeLiquidity(
    address account,
    address tokenOut,
    address receiver
  ) external returns (uint256);

  function renounceOwnership() external;

  function reservedOf(address) external view returns (uint256);

  function setPoolConfig(address newPoolConfig) external;

  function setPoolMath(address newPoolMath) external;

  function setPoolOracle(address newPoolOracle) external;

  function shortAveragePriceOf(address) external view returns (uint256);

  function shortSizeOf(address) external view returns (uint256);

  function sumBorrowingRateOf(address) external view returns (uint256);

  function swap(
    address tokenIn,
    address tokenOut,
    uint256 minAmountOut,
    address receiver
  ) external returns (uint256);

  function totalOf(address) external view returns (uint256);

  function totalUsdDebt() external view returns (uint256);

  function transferOwnership(address newOwner) external;

  function updateFundingRate(address collateralToken, address indexToken)
    external;

  function usdDebtOf(address) external view returns (uint256);

  function withdrawFeeReserve(
    address token,
    address to,
    uint256 amount
  ) external;
}
