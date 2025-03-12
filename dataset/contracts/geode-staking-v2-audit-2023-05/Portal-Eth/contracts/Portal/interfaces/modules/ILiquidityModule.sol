// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface ILiquidityModule {
  function pause() external;

  function unpause() external;

  function LiquidityParams()
    external
    view
    returns (
      address gETH,
      address lpToken,
      uint256 pooledTokenId,
      uint256 initialA,
      uint256 futureA,
      uint256 initialATime,
      uint256 futureATime,
      uint256 swapFee,
      uint256 adminFee
    );

  function getA() external view returns (uint256);

  function getAPrecise() external view returns (uint256);

  function getBalance(uint8 index) external view returns (uint256);

  function getDebt() external view returns (uint256);

  function getVirtualPrice() external view returns (uint256);

  function getAdminBalance(uint256 index) external view returns (uint256);

  function calculateSwap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx
  ) external view returns (uint256);

  function calculateTokenAmount(
    uint256[2] calldata amounts,
    bool deposit
  ) external view returns (uint256);

  function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[2] memory);

  function calculateRemoveLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex
  ) external view returns (uint256 availableTokenAmount);

  function swap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline
  ) external payable returns (uint256);

  function addLiquidity(
    uint256[2] calldata amounts,
    uint256 minToMint,
    uint256 deadline
  ) external payable returns (uint256);

  function removeLiquidity(
    uint256 amount,
    uint256[2] calldata minAmounts,
    uint256 deadline
  ) external returns (uint256[2] memory);

  function removeLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex,
    uint256 minAmount,
    uint256 deadline
  ) external returns (uint256);

  function removeLiquidityImbalance(
    uint256[2] calldata amounts,
    uint256 maxBurnAmount,
    uint256 deadline
  ) external returns (uint256);

  function withdrawAdminFees(address receiver) external;

  function setAdminFee(uint256 newAdminFee) external;

  function setSwapFee(uint256 newSwapFee) external;

  function rampA(uint256 futureA, uint256 futureTime) external;

  function stopRampA() external;
}
