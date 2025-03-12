// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {IPoolDataProvider} from "aave-v3/interfaces/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "aave-v3/interfaces/IPoolAddressesProvider.sol";

contract PoolDataProvider is IPoolDataProvider {

  constructor( ) { }

  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider) {}

  function getAllReservesTokens() external view returns (TokenData[] memory) {}

  function getAllATokens() external view returns (TokenData[] memory) {}

  function getReserveConfigurationData(address asset)
    external
    view
    returns (
      uint256 decimals,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      uint256 reserveFactor,
      bool usageAsCollateralEnabled,
      bool borrowingEnabled,
      bool stableBorrowRateEnabled,
      bool isActive,
      bool isFrozen
    ) {}

  function getReserveEModeCategory(address asset) external view returns (uint256) {}

  function getReserveCaps(address asset)
    external
    view
    returns (uint256 borrowCap, uint256 supplyCap) {}

  function getPaused(address asset) external view returns (bool isPaused) {}

  function getSiloedBorrowing(address asset) external view returns (bool) {}

  function getLiquidationProtocolFee(address asset) external view returns (uint256) {}

  function getUnbackedMintCap(address asset) external view returns (uint256) {}

  function getDebtCeiling(address asset) external view returns (uint256) {}

  function getDebtCeilingDecimals() external pure returns (uint256) {}

  function getReserveData(address asset)
    external
    view
    returns (
      uint256 unbacked,
      uint256 accruedToTreasuryScaled,
      uint256 totalAToken,
      uint256 totalStableDebt,
      uint256 totalVariableDebt,
      uint256 liquidityRate,
      uint256 variableBorrowRate,
      uint256 stableBorrowRate,
      uint256 averageStableBorrowRate,
      uint256 liquidityIndex,
      uint256 variableBorrowIndex,
      uint40 lastUpdateTimestamp
    ) {}

  function getATokenTotalSupply(address asset) external view returns (uint256) {}

  function getTotalDebt(address asset) external view returns (uint256) {}

  function getUserReserveData(address asset, address user)
    external
    view
    returns (
      uint256 currentATokenBalance,
      uint256 currentStableDebt,
      uint256 currentVariableDebt,
      uint256 principalStableDebt,
      uint256 scaledVariableDebt,
      uint256 stableBorrowRate,
      uint256 liquidityRate,
      uint40 stableRateLastUpdated,
      bool usageAsCollateralEnabled
    ) {}

  function getReserveTokensAddresses(address asset)
    external
    view
    returns (
      address aTokenAddress,
      address stableDebtTokenAddress,
      address variableDebtTokenAddress
    ) {}

  function getInterestRateStrategyAddress(address asset)
    external
    view
    returns (address irStrategyAddress) {}

  function getFlashLoanEnabled(address asset) external view returns (bool) {}

}