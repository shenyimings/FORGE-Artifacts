// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IAToken} from "src/interfaces/aave/IAToken.sol";

import {Types} from "src/libraries/Types.sol";
import {ReserveDataLib} from "src/libraries/ReserveDataLib.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {ReserveConfiguration} from "@aave-v3-core/protocol/libraries/configuration/ReserveConfiguration.sol";
import {WadRayMath} from "@morpho-utils/math/WadRayMath.sol";
import {Math} from "@morpho-utils/math/Math.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";

library ReserveDataTestLib {
    using Math for uint256;
    using WadRayMath for uint256;

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    /// @dev Returns the quantity currently supplied on the market on AaveV3.
    function totalSupply(DataTypes.ReserveData memory reserve) internal view returns (uint256) {
        return ERC20(reserve.aTokenAddress).totalSupply();
    }

    /// @dev Returns the quantity currently borrowed (with variable & stable rates) on the market on AaveV3.
    function totalBorrow(DataTypes.ReserveData memory reserve) internal view returns (uint256) {
        return totalVariableBorrow(reserve) + totalStableBorrow(reserve);
    }

    /// @dev Returns the quantity currently borrowed with variable rate from the market on AaveV3.
    function totalVariableBorrow(DataTypes.ReserveData memory reserve) internal view returns (uint256) {
        return ERC20(reserve.variableDebtTokenAddress).totalSupply();
    }

    /// @dev Returns the quantity currently borrowed with stable rate from the market on AaveV3.
    function totalStableBorrow(DataTypes.ReserveData memory reserve) internal view returns (uint256) {
        return ERC20(reserve.stableDebtTokenAddress).totalSupply();
    }

    /// @dev Returns the quantity currently supplied on behalf of the user, on the market on AaveV3.
    function supplyOf(DataTypes.ReserveData memory reserve, address user) internal view returns (uint256) {
        return ERC20(reserve.aTokenAddress).balanceOf(user);
    }

    /// @dev Returns the quantity currently borrowed on behalf of the user, with variable rate, on the market on AaveV3.
    function variableBorrowOf(DataTypes.ReserveData memory reserve, address user) internal view returns (uint256) {
        return ERC20(reserve.variableDebtTokenAddress).balanceOf(user);
    }

    /// @dev Returns the quantity currently borrowed on behalf of the user, with stable rate, on the market on AaveV3.
    function stableBorrowOf(DataTypes.ReserveData memory reserve, address user) internal view returns (uint256) {
        return ERC20(reserve.stableDebtTokenAddress).balanceOf(user);
    }

    /// @dev Returns the total supply used towards the supply cap.
    function totalSupplyToCap(DataTypes.ReserveData memory reserve, uint256 poolSupplyIndex, uint256 poolBorrowIndex)
        internal
        view
        returns (uint256)
    {
        return (
            IAToken(reserve.aTokenAddress).scaledTotalSupply()
                + ReserveDataLib.getAccruedToTreasury(
                    reserve,
                    Types.Indexes256({
                        supply: Types.MarketSideIndexes256({p2pIndex: 0, poolIndex: poolSupplyIndex}),
                        borrow: Types.MarketSideIndexes256({p2pIndex: 0, poolIndex: poolBorrowIndex})
                    })
                )
        ).rayMul(poolSupplyIndex);
    }

    /// @dev Calculates the underlying amount that can be supplied on the given market on AaveV3, reaching the supply cap.
    function supplyGap(DataTypes.ReserveData memory reserve, uint256 poolSupplyIndex, uint256 poolBorrowIndex)
        internal
        view
        returns (uint256)
    {
        return (reserve.configuration.getSupplyCap() * 10 ** reserve.configuration.getDecimals()).zeroFloorSub(
            totalSupplyToCap(reserve, poolSupplyIndex, poolBorrowIndex)
        );
    }

    /// @dev Calculates the underlying amount that can be borrowed on the given market on AaveV3, reaching the borrow cap.
    function borrowGap(DataTypes.ReserveData memory reserve) internal view returns (uint256) {
        return (reserve.configuration.getBorrowCap() * 10 ** reserve.configuration.getDecimals()).zeroFloorSub(
            totalBorrow(reserve)
        );
    }
}
