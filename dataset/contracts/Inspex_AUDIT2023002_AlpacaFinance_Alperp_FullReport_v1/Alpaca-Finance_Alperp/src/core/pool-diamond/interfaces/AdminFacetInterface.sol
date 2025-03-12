// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/
pragma solidity 0.8.17;

import { PoolOracle } from "../../PoolOracle.sol";

import { LibPoolConfigV1 } from "../libraries/LibPoolConfigV1.sol";

interface AdminFacetInterface {
  function deleteTokenConfig(address token) external;

  function setAllowLiquidators(address[] memory liquidators, bool allow)
    external;

  function setFlashLoanFeeBps(uint64 newFlashLoanFeeBps) external;

  function setFundingRate(
    uint64 newFundingInterval,
    uint64 newBorrowingRateFactor,
    uint64 newStableBorrowingRateFactor,
    uint64 newFundingRateFactor
  ) external;

  function setIsAllowAllLiquidators(bool _isAllowAllLiquidators) external;

  function setIsDynamicFeeEnable(bool newIsDynamicFeeEnable) external;

  function setIsLeverageEnable(bool newIsLeverageEnable) external;

  function setIsSwapEnable(bool newIsSwapEnable) external;

  function setLiquidationFeeUsd(uint256 newLiquidationFeeUsd) external;

  function setMaxLeverage(uint64 newMaxLeverage) external;

  function setMinProfitDuration(uint64 newMinProfitDuration) external;

  function setMintBurnFeeBps(uint64 newMintBurnFeeBps) external;

  function setPoolOracle(PoolOracle newPoolOracle) external;

  function setPositionFeeBps(uint64 newPositionFeeBps) external;

  function setRouter(address newRouter) external;

  function setSwapFeeBps(uint64 newSwapFeeBps, uint64 newStableSwapFeeBps)
    external;

  function setTaxBps(uint64 newTaxBps, uint64 newStableTaxBps) external;

  function setTokenConfigs(
    address[] memory tokens,
    LibPoolConfigV1.TokenConfig[] memory configs
  ) external;

  function setTreasury(address newTreasury) external;

  function withdrawFeeReserve(
    address token,
    address to,
    uint256 amount
  ) external;

  function setPlugin(address plugin, bool allow) external;
}
