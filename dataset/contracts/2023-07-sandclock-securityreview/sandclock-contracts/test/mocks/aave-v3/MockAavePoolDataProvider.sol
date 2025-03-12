// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {IPoolDataProvider} from "aave-v3/interfaces/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "aave-v3/interfaces/IPoolAddressesProvider.sol";

contract MockAavePoolDataProvider is IPoolDataProvider {
    mapping(address => uint256) public ltvMap;

    constructor(address usdc, address weth) {
        ltvMap[usdc] = 8000;
        ltvMap[weth] = 8000;
    }

    function setLtv(address asset, uint256 ltv) external {
        ltvMap[asset] = ltv;
    }

    function getReserveConfigurationData(address asset)
        external
        view
        override
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
        )
    {}

    /*//////////////////////////////////////////////////////////////
                            UNUSED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {}

    function getAllReservesTokens() external view override returns (TokenData[] memory) {}

    function getAllATokens() external view override returns (TokenData[] memory) {}

    function getReserveEModeCategory(address asset) external view override returns (uint256) {}

    function getReserveCaps(address asset) external view override returns (uint256 borrowCap, uint256 supplyCap) {}

    function getPaused(address asset) external view override returns (bool isPaused) {}

    function getSiloedBorrowing(address asset) external view override returns (bool) {}

    function getLiquidationProtocolFee(address asset) external view override returns (uint256) {}

    function getUnbackedMintCap(address asset) external view override returns (uint256) {}

    function getDebtCeiling(address asset) external view override returns (uint256) {}

    function getDebtCeilingDecimals() external pure override returns (uint256) {}

    function getReserveData(address asset)
        external
        view
        override
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
        )
    {}

    function getATokenTotalSupply(address asset) external view override returns (uint256) {}

    function getTotalDebt(address asset) external view override returns (uint256) {}

    function getUserReserveData(address asset, address user)
        external
        view
        override
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
        )
    {}

    function getReserveTokensAddresses(address asset)
        external
        view
        override
        returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress)
    {}

    function getInterestRateStrategyAddress(address asset) external view override returns (address irStrategyAddress) {}

    function getFlashLoanEnabled(address asset) external view override returns (bool) {}
}
