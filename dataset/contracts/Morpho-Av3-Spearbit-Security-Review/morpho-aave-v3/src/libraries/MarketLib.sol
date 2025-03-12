// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IAToken} from "../interfaces/aave/IAToken.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";

import {Types} from "./Types.sol";
import {Events} from "./Events.sol";
import {Errors} from "./Errors.sol";
import {ReserveDataLib} from "./ReserveDataLib.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {WadRayMath} from "@morpho-utils/math/WadRayMath.sol";
import {PercentageMath} from "@morpho-utils/math/PercentageMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {ReserveConfiguration} from "@aave-v3-core/protocol/libraries/configuration/ReserveConfiguration.sol";

/// @title MarketLib
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Library used to ease market reads and writes.
library MarketLib {
    using Math for uint256;
    using SafeCast for uint256;
    using WadRayMath for uint256;

    using ReserveDataLib for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function isCreated(Types.Market storage market) internal view returns (bool) {
        return market.aToken != address(0);
    }

    function isSupplyPaused(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isSupplyPaused;
    }

    function isSupplyCollateralPaused(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isSupplyCollateralPaused;
    }

    function isBorrowPaused(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isBorrowPaused;
    }

    function isRepayPaused(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isRepayPaused;
    }

    function isWithdrawPaused(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isWithdrawPaused;
    }

    function isWithdrawCollateralPaused(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isWithdrawCollateralPaused;
    }

    function isLiquidateCollateralPaused(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isLiquidateCollateralPaused;
    }

    function isLiquidateBorrowPaused(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isLiquidateBorrowPaused;
    }

    function isDeprecated(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isDeprecated;
    }

    function isP2PDisabled(Types.Market storage market) internal view returns (bool) {
        return market.pauseStatuses.isP2PDisabled;
    }

    function setIsSupplyPaused(Types.Market storage market, bool isPaused) internal {
        market.pauseStatuses.isSupplyPaused = isPaused;

        emit Events.IsSupplyPausedSet(market.underlying, isPaused);
    }

    function setIsSupplyCollateralPaused(Types.Market storage market, bool isPaused) internal {
        market.pauseStatuses.isSupplyCollateralPaused = isPaused;

        emit Events.IsSupplyCollateralPausedSet(market.underlying, isPaused);
    }

    function setIsBorrowPaused(Types.Market storage market, bool isPaused) internal {
        market.pauseStatuses.isBorrowPaused = isPaused;

        emit Events.IsBorrowPausedSet(market.underlying, isPaused);
    }

    function setIsRepayPaused(Types.Market storage market, bool isPaused) internal {
        market.pauseStatuses.isRepayPaused = isPaused;

        emit Events.IsRepayPausedSet(market.underlying, isPaused);
    }

    function setIsWithdrawPaused(Types.Market storage market, bool isPaused) internal {
        market.pauseStatuses.isWithdrawPaused = isPaused;

        emit Events.IsWithdrawPausedSet(market.underlying, isPaused);
    }

    function setIsWithdrawCollateralPaused(Types.Market storage market, bool isPaused) internal {
        market.pauseStatuses.isWithdrawCollateralPaused = isPaused;

        emit Events.IsWithdrawCollateralPausedSet(market.underlying, isPaused);
    }

    function setIsLiquidateCollateralPaused(Types.Market storage market, bool isPaused) internal {
        market.pauseStatuses.isLiquidateCollateralPaused = isPaused;

        emit Events.IsLiquidateCollateralPausedSet(market.underlying, isPaused);
    }

    function setIsLiquidateBorrowPaused(Types.Market storage market, bool isPaused) internal {
        market.pauseStatuses.isLiquidateBorrowPaused = isPaused;

        emit Events.IsLiquidateBorrowPausedSet(market.underlying, isPaused);
    }

    function setIsDeprecated(Types.Market storage market, bool deprecated) internal {
        market.pauseStatuses.isDeprecated = deprecated;

        emit Events.IsDeprecatedSet(market.underlying, deprecated);
    }

    function setIsP2PDisabled(Types.Market storage market, bool p2pDisabled) internal {
        market.pauseStatuses.isP2PDisabled = p2pDisabled;

        emit Events.IsP2PDisabledSet(market.underlying, p2pDisabled);
    }

    function setReserveFactor(Types.Market storage market, uint16 reserveFactor) internal {
        if (reserveFactor > PercentageMath.PERCENTAGE_FACTOR) revert Errors.ExceedsMaxBasisPoints();
        market.reserveFactor = reserveFactor;

        emit Events.ReserveFactorSet(market.underlying, reserveFactor);
    }

    function setP2PIndexCursor(Types.Market storage market, uint16 p2pIndexCursor) internal {
        if (p2pIndexCursor > PercentageMath.PERCENTAGE_FACTOR) revert Errors.ExceedsMaxBasisPoints();
        market.p2pIndexCursor = p2pIndexCursor;

        emit Events.P2PIndexCursorSet(market.underlying, p2pIndexCursor);
    }

    function setIndexes(Types.Market storage market, Types.Indexes256 memory indexes) internal {
        market.indexes.supply.poolIndex = indexes.supply.poolIndex.toUint128();
        market.indexes.supply.p2pIndex = indexes.supply.p2pIndex.toUint128();
        market.indexes.borrow.poolIndex = indexes.borrow.poolIndex.toUint128();
        market.indexes.borrow.p2pIndex = indexes.borrow.p2pIndex.toUint128();
        market.lastUpdateTimestamp = uint32(block.timestamp);
        emit Events.IndexesUpdated(
            market.underlying,
            indexes.supply.poolIndex,
            indexes.supply.p2pIndex,
            indexes.borrow.poolIndex,
            indexes.borrow.p2pIndex
            );
    }

    function getSupplyIndexes(Types.Market storage market)
        internal
        view
        returns (Types.MarketSideIndexes256 memory supplyIndexes)
    {
        supplyIndexes.poolIndex = uint256(market.indexes.supply.poolIndex);
        supplyIndexes.p2pIndex = uint256(market.indexes.supply.p2pIndex);
    }

    function getBorrowIndexes(Types.Market storage market)
        internal
        view
        returns (Types.MarketSideIndexes256 memory borrowIndexes)
    {
        borrowIndexes.poolIndex = uint256(market.indexes.borrow.poolIndex);
        borrowIndexes.p2pIndex = uint256(market.indexes.borrow.p2pIndex);
    }

    function getIndexes(Types.Market storage market) internal view returns (Types.Indexes256 memory indexes) {
        indexes.supply = getSupplyIndexes(market);
        indexes.borrow = getBorrowIndexes(market);
    }

    function getProportionIdle(Types.Market storage market) internal view returns (uint256) {
        uint256 idleSupply = market.idleSupply;
        if (idleSupply == 0) return 0;

        uint256 totalP2PSupplied = market.deltas.supply.scaledP2PTotal.rayMul(market.indexes.supply.p2pIndex);
        return idleSupply.rayDivUp(totalP2PSupplied);
    }

    /// @dev Increases the idle supply if the supply cap is reached in a breaking repay, and returns a new toSupply amount.
    /// @param market The market storage.
    /// @param underlying The underlying address.
    /// @param amount The amount to repay. (by supplying on pool)
    /// @param reserve The reserve data for the market.
    /// @return The amount to supply to stay below the supply cap and the amount the idle supply was increased by.
    function increaseIdle(
        Types.Market storage market,
        address underlying,
        uint256 amount,
        DataTypes.ReserveData memory reserve,
        Types.Indexes256 memory indexes
    ) internal returns (uint256, uint256) {
        uint256 supplyCap = reserve.configuration.getSupplyCap() * (10 ** reserve.configuration.getDecimals());
        if (supplyCap == 0) return (amount, 0);

        uint256 suppliable = supplyCap.zeroFloorSub(
            (IAToken(market.aToken).scaledTotalSupply() + reserve.getAccruedToTreasury(indexes)).rayMul(
                indexes.supply.poolIndex
            )
        );
        if (amount <= suppliable) return (amount, 0);

        uint256 idleSupplyIncrease = amount - suppliable;
        uint256 newIdleSupply = market.idleSupply + idleSupplyIncrease;

        market.idleSupply = newIdleSupply;

        emit Events.IdleSupplyUpdated(underlying, newIdleSupply);

        return (suppliable, idleSupplyIncrease);
    }

    /// @dev Decreases the idle supply.
    /// @param market The market storage.
    /// @param underlying The underlying address.
    /// @param amount The amount to borrow.
    /// @return The amount left to process and the processed amount.
    function decreaseIdle(Types.Market storage market, address underlying, uint256 amount)
        internal
        returns (uint256, uint256)
    {
        if (amount == 0) return (0, 0);

        uint256 idleSupply = market.idleSupply;
        if (idleSupply == 0) return (amount, 0);

        uint256 matchedIdle = Math.min(idleSupply, amount); // In underlying.
        uint256 newIdleSupply = idleSupply.zeroFloorSub(matchedIdle);
        market.idleSupply = newIdleSupply;

        emit Events.IdleSupplyUpdated(underlying, newIdleSupply);

        return (amount - matchedIdle, matchedIdle);
    }
}
