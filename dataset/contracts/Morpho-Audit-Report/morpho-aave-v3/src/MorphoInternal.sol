// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IRewardsManager} from "./interfaces/IRewardsManager.sol";
import {IAaveOracle} from "@aave-v3-core/interfaces/IAaveOracle.sol";

import {Types} from "./libraries/Types.sol";
import {Events} from "./libraries/Events.sol";
import {Errors} from "./libraries/Errors.sol";
import {PoolLib} from "./libraries/PoolLib.sol";
import {MarketLib} from "./libraries/MarketLib.sol";
import {DeltasLib} from "./libraries/DeltasLib.sol";
import {Constants} from "./libraries/Constants.sol";
import {MarketBalanceLib} from "./libraries/MarketBalanceLib.sol";
import {InterestRatesLib} from "./libraries/InterestRatesLib.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {WadRayMath} from "@morpho-utils/math/WadRayMath.sol";
import {PercentageMath} from "@morpho-utils/math/PercentageMath.sol";

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {LogarithmicBuckets} from "@morpho-data-structures/LogarithmicBuckets.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {UserConfiguration} from "@aave-v3-core/protocol/libraries/configuration/UserConfiguration.sol";
import {ReserveConfiguration} from "@aave-v3-core/protocol/libraries/configuration/ReserveConfiguration.sol";

import {MorphoStorage} from "./MorphoStorage.sol";

/// @title MorphoInternal
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Abstract contract exposing `Morpho`'s internal functions.
abstract contract MorphoInternal is MorphoStorage {
    using PoolLib for IPool;
    using MarketLib for Types.Market;
    using DeltasLib for Types.Deltas;
    using MarketBalanceLib for Types.MarketBalances;

    using Math for uint256;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    using SafeTransferLib for ERC20;

    using EnumerableSet for EnumerableSet.AddressSet;
    using LogarithmicBuckets for LogarithmicBuckets.Buckets;

    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    /* INTERNAL */

    /// @dev Dynamically computed to use the root proxy address in a delegate call.
    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                Constants.EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(Constants.EIP712_NAME)),
                keccak256(bytes(Constants.EIP712_VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    /// @dev Creates a new market for the `underlying` token with a given `reserveFactor` (in bps) and a given `p2pIndexCursor` (in bps).
    function _createMarket(address underlying, uint16 reserveFactor, uint16 p2pIndexCursor) internal {
        if (underlying == address(0)) revert Errors.AddressIsZero();

        DataTypes.ReserveData memory reserve = _pool.getReserveData(underlying);
        if (!reserve.configuration.getActive()) revert Errors.MarketIsNotListedOnAave();
        if (reserve.configuration.getSiloedBorrowing()) revert Errors.SiloedBorrowMarket();

        // `liquidationThreshold < Constants.LT_LOWER_BOUND` checks that the asset's LT is not too low to be listed as a collateral on Morpho.
        // If the LT is 0, the check is skipped to be able to create markets for non-collateral assets.
        // In the case where the "standard" LT is below the `LT_LOWER_BOUND` while the eMode LT is higher, the check will still revert for safety.
        uint256 liquidationThreshold = reserve.configuration.getLiquidationThreshold();
        if (liquidationThreshold > 0 && liquidationThreshold < Constants.LT_LOWER_BOUND) {
            revert Errors.MarketLtTooLow();
        }

        Types.Market storage market = _market[underlying];

        if (market.isCreated()) revert Errors.MarketAlreadyCreated();

        market.underlying = underlying;
        market.aToken = reserve.aTokenAddress;
        market.variableDebtToken = reserve.variableDebtTokenAddress;
        market.stableDebtToken = reserve.stableDebtTokenAddress;

        _marketsCreated.push(underlying);

        emit Events.MarketCreated(underlying);

        Types.Indexes256 memory indexes;
        (indexes.supply.poolIndex, indexes.borrow.poolIndex) = _pool.getCurrentPoolIndexes(underlying);
        indexes.supply.p2pIndex = WadRayMath.RAY;
        indexes.borrow.p2pIndex = WadRayMath.RAY;

        market.setIndexes(indexes);
        market.setReserveFactor(reserveFactor);
        market.setP2PIndexCursor(p2pIndexCursor);

        ERC20(underlying).safeApprove(address(_pool), type(uint256).max);
    }

    /// @dev Claims the fee for the `underlyings` and send it to the `_treasuryVault`.
    ///      Claiming on a market where there are some rewards might steal users' rewards.
    function _claimToTreasury(address[] calldata underlyings, uint256[] calldata amounts) internal {
        address treasuryVault = _treasuryVault;
        if (treasuryVault == address(0)) revert Errors.AddressIsZero();

        for (uint256 i; i < underlyings.length; ++i) {
            address underlying = underlyings[i];
            Types.Market storage market = _market[underlying];

            if (!market.isCreated()) continue;

            uint256 claimable = ERC20(underlying).balanceOf(address(this)) - market.idleSupply;
            uint256 claimed = Math.min(amounts[i], claimable);

            if (claimed == 0) continue;

            ERC20(underlying).safeTransfer(treasuryVault, claimed);
            emit Events.ReserveFeeClaimed(underlying, claimed);
        }
    }

    /// @dev Increases the peer-to-peer delta of `amount` on the `underlying` market.
    /// @dev Note that this can fail if the amount is too big. In this case, consider splitting in multiple calls/txs.
    function _increaseP2PDeltas(address underlying, uint256 amount) internal {
        Types.Indexes256 memory indexes = _updateIndexes(underlying);

        Types.Market storage market = _market[underlying];
        Types.Deltas storage deltas = market.deltas;
        uint256 poolSupplyIndex = indexes.supply.poolIndex;
        uint256 poolBorrowIndex = indexes.borrow.poolIndex;

        amount = Math.min(amount, Math.min(market.trueP2PSupply(indexes), market.trueP2PBorrow(indexes)));
        if (amount == 0) revert Errors.AmountIsZero();

        uint256 newSupplyDelta = deltas.supply.scaledDelta + amount.rayDiv(poolSupplyIndex);
        uint256 newBorrowDelta = deltas.borrow.scaledDelta + amount.rayDiv(poolBorrowIndex);

        deltas.supply.scaledDelta = newSupplyDelta;
        deltas.borrow.scaledDelta = newBorrowDelta;
        emit Events.P2PSupplyDeltaUpdated(underlying, newSupplyDelta);
        emit Events.P2PBorrowDeltaUpdated(underlying, newBorrowDelta);

        _pool.borrowFromPool(underlying, amount);
        _pool.supplyToPool(underlying, amount, poolSupplyIndex);

        emit Events.P2PDeltasIncreased(underlying, amount);
    }

    /// @dev Returns the hash of the EIP712 typed data.
    function _hashEIP712TypedData(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(Constants.EIP712_MSG_PREFIX, _domainSeparator(), structHash));
    }

    /// @dev Approves a `manager` to borrow/withdraw on behalf of the `delegator`.
    /// @param delegator The address of the delegator.
    /// @param manager The address of the manager.
    /// @param isAllowed Whether `manager` is allowed to manage `delegator`'s position or not.
    function _approveManager(address delegator, address manager, bool isAllowed) internal {
        _isManagedBy[delegator][manager] = isAllowed;
        emit Events.ManagerApproval(delegator, manager, isAllowed);
    }

    /// @dev Returns the total supply balance of `user` on the `underlying` market given `indexes` (in underlying).
    function _getUserSupplyBalanceFromIndexes(address underlying, address user, Types.Indexes256 memory indexes)
        internal
        view
        returns (uint256)
    {
        Types.MarketBalances storage marketBalances = _marketBalances[underlying];

        return marketBalances.scaledPoolSupplyBalance(user).rayMulDown(indexes.supply.poolIndex)
            + marketBalances.scaledP2PSupplyBalance(user).rayMulDown(indexes.supply.p2pIndex);
    }

    /// @dev Returns the total borrow balance of `user` on the `underlying` market given `indexes` (in underlying).
    function _getUserBorrowBalanceFromIndexes(address underlying, address user, Types.Indexes256 memory indexes)
        internal
        view
        returns (uint256)
    {
        Types.MarketBalances storage marketBalances = _marketBalances[underlying];

        return marketBalances.scaledPoolBorrowBalance(user).rayMulUp(indexes.borrow.poolIndex)
            + marketBalances.scaledP2PBorrowBalance(user).rayMulUp(indexes.borrow.p2pIndex);
    }

    /// @dev Returns the collateral balance of `user` on the `underlying` market a `poolSupplyIndex` (in underlying).
    function _getUserCollateralBalanceFromIndex(address underlying, address user, uint256 poolSupplyIndex)
        internal
        view
        returns (uint256)
    {
        return _marketBalances[underlying].scaledCollateralBalance(user).rayMulDown(poolSupplyIndex);
    }

    /// @dev Returns the buckets of a particular side of a market.
    /// @param underlying The address of the underlying asset.
    /// @param position The side of the market.
    function _getBuckets(address underlying, Types.Position position)
        internal
        view
        returns (LogarithmicBuckets.Buckets storage)
    {
        if (position == Types.Position.POOL_SUPPLIER) {
            return _marketBalances[underlying].poolSuppliers;
        } else if (position == Types.Position.P2P_SUPPLIER) {
            return _marketBalances[underlying].p2pSuppliers;
        } else if (position == Types.Position.POOL_BORROWER) {
            return _marketBalances[underlying].poolBorrowers;
        } else {
            return _marketBalances[underlying].p2pBorrowers;
        }
    }

    /// @notice Returns the liquidity data about the position of `user`.
    /// @param user The address of the user to get the liquidity data for.
    /// @return liquidityData The liquidity data of the user.
    function _liquidityData(address user) internal view returns (Types.LiquidityData memory liquidityData) {
        Types.LiquidityVars memory vars;

        if (_eModeCategoryId != 0) vars.eModeCategory = _pool.getEModeCategoryData(_eModeCategoryId);
        vars.oracle = IAaveOracle(_addressesProvider.getPriceOracle());
        vars.user = user;

        (liquidityData.borrowable, liquidityData.maxDebt) = _totalCollateralData(vars);
        liquidityData.debt = _totalDebt(vars);
    }

    /// @dev Returns the collateral data for a given set of inputs.
    /// @dev The total collateral data is computed looping through all user's collateral assets.
    /// @param vars The liquidity variables.
    /// @return borrowable The total borrowable amount of `vars.user`.
    /// @return maxDebt The total maximum debt of `vars.user`.
    function _totalCollateralData(Types.LiquidityVars memory vars)
        internal
        view
        returns (uint256 borrowable, uint256 maxDebt)
    {
        address[] memory userCollaterals = _userCollaterals[vars.user].values();

        for (uint256 i; i < userCollaterals.length; ++i) {
            (uint256 borrowableSingle, uint256 maxDebtSingle) = _collateralData(userCollaterals[i], vars);

            borrowable += borrowableSingle;
            maxDebt += maxDebtSingle;
        }
    }

    /// @dev Returns the debt data for a given set of inputs.
    /// @dev The total debt data is computed iterating through all user's borrow assets.
    /// @param vars The liquidity variables.
    /// @return debt The total debt of `vars.user`.
    function _totalDebt(Types.LiquidityVars memory vars) internal view returns (uint256 debt) {
        address[] memory userBorrows = _userBorrows[vars.user].values();

        for (uint256 i; i < userBorrows.length; ++i) {
            debt += _debt(userBorrows[i], vars);
        }
    }

    /// @dev Returns the collateral data for a given set of inputs.
    /// @param underlying The address of the underlying collateral asset.
    /// @param vars The liquidity variables.
    /// @return borrowable The borrowable amount of `vars.user` on the `underlying` market.
    /// @return maxDebt The maximum debt of `vars.user` on the `underlying` market.
    function _collateralData(address underlying, Types.LiquidityVars memory vars)
        internal
        view
        returns (uint256 borrowable, uint256 maxDebt)
    {
        if (!_market[underlying].isCollateral) return (0, 0);

        (uint256 underlyingPrice, uint256 ltv, uint256 liquidationThreshold, uint256 underlyingUnit) =
            _assetLiquidityData(underlying, vars);

        Types.Indexes256 memory indexes = _computeIndexes(underlying);
        uint256 rawCollateral = (
            (_getUserCollateralBalanceFromIndex(underlying, vars.user, indexes.supply.poolIndex)) * underlyingPrice
        ) / underlyingUnit;

        // Morpho has a slightly different method of health factor calculation from the underlying pool.
        // This method is used to account for a potential rounding error in calculateUserAccountData,
        // see https://github.com/aave/aave-v3-core/blob/94e571f3a7465201881a59555314cd550ccfda57/contracts/protocol/libraries/logic/GenericLogic.sol#L64-L196
        // To resolve this, Morpho reduces the collateral value by a small amount.
        uint256 collateral = ((Constants.LT_LOWER_BOUND - 1) * rawCollateral) / Constants.LT_LOWER_BOUND;

        borrowable = collateral.percentMulDown(ltv);
        maxDebt = collateral.percentMulDown(liquidationThreshold);
    }

    /// @dev Returns the debt value for a given set of inputs.
    /// @param underlying The address of the underlying asset to borrow.
    /// @param vars The liquidity variables.
    /// @return debtValue The debt value of `vars.user` on the `underlying` market.
    function _debt(address underlying, Types.LiquidityVars memory vars) internal view returns (uint256 debtValue) {
        DataTypes.ReserveConfigurationMap memory config = _pool.getConfiguration(underlying);
        (, uint256 underlyingPrice, uint256 underlyingUnit) =
            _assetData(underlying, vars.oracle, config, vars.eModeCategory.priceSource);

        Types.Indexes256 memory indexes = _computeIndexes(underlying);
        debtValue =
            (_getUserBorrowBalanceFromIndexes(underlying, vars.user, indexes) * underlyingPrice).divUp(underlyingUnit);
    }

    /// @dev Returns the liquidity data for a given set of inputs.
    /// @param underlying The address of the underlying asset.
    /// @param vars The liquidity variables.
    /// @return underlyingPrice The price of the underlying asset (in base currency).
    /// @return ltv The loan to value of the underlying asset.
    /// @return liquidationThreshold The liquidation threshold of the underlying asset.
    /// @return underlyingUnit The token unit of the underlying asset.
    function _assetLiquidityData(address underlying, Types.LiquidityVars memory vars)
        internal
        view
        returns (uint256 underlyingPrice, uint256 ltv, uint256 liquidationThreshold, uint256 underlyingUnit)
    {
        DataTypes.ReserveConfigurationMap memory config = _pool.getConfiguration(underlying);

        bool isInEMode;
        (isInEMode, underlyingPrice, underlyingUnit) =
            _assetData(underlying, vars.oracle, config, vars.eModeCategory.priceSource);

        // If the LTV is 0 on Aave V3, the asset cannot be used as collateral to borrow upon a breaking withdraw.
        // In response, Morpho disables the asset as collateral and sets its liquidation threshold
        // to 0 and the governance should warn users to repay their debt.
        if (config.getLtv() == 0) return (underlyingPrice, 0, 0, underlyingUnit);

        if (isInEMode) {
            ltv = vars.eModeCategory.ltv;
            liquidationThreshold = vars.eModeCategory.liquidationThreshold;
        } else {
            ltv = config.getLtv();
            liquidationThreshold = config.getLiquidationThreshold();
        }
    }

    /// @dev Prompts the rewards manager (if set) to accrue a user's rewards.
    /// @param user The address of the user to accrue rewards for.
    /// @param poolToken The address of the pool token related to this market (aToken or variable debt token address).
    /// @param formerOnPool The former scaled balance on pool of the `user`.
    function _updateRewards(address user, address poolToken, uint256 formerOnPool) internal {
        IRewardsManager rewardsManager = _rewardsManager;
        if (address(rewardsManager) != address(0)) {
            rewardsManager.updateUserRewards(user, poolToken, formerOnPool);
        }
    }

    /// @dev Updates a `user`'s position in the data structure.
    /// @param poolToken The address of the pool token related to this market (aToken or variable debt token address).
    /// @param user The address of the user to update.
    /// @param poolBuckets The pool buckets.
    /// @param p2pBuckets The peer-to-peer buckets.
    /// @param onPool The new scaled balance on pool of the `user`.
    /// @param inP2P The new scaled balance in peer-to-peer of the `user`.
    /// @param demoting Whether the update is happening during a demoting process or not.
    /// @return The actual new scaled balance on pool and in peer-to-peer of the `user` after accounting for dust.
    function _updateInDS(
        address poolToken,
        address user,
        LogarithmicBuckets.Buckets storage poolBuckets,
        LogarithmicBuckets.Buckets storage p2pBuckets,
        uint256 onPool,
        uint256 inP2P,
        bool demoting
    ) internal returns (uint256, uint256) {
        if (onPool <= Constants.DUST_THRESHOLD) onPool = 0;
        if (inP2P <= Constants.DUST_THRESHOLD) inP2P = 0;

        uint256 formerOnPool = poolBuckets.valueOf[user];
        uint256 formerInP2P = p2pBuckets.valueOf[user];

        if (onPool != formerOnPool) {
            _updateRewards(user, poolToken, formerOnPool);
            poolBuckets.update(user, onPool, demoting);
        }

        if (inP2P != formerInP2P) p2pBuckets.update(user, inP2P, true);
        return (onPool, inP2P);
    }

    /// @dev Updates a `user`'s supply position in the data structure.
    /// @param underlying The address of the underlying asset.
    /// @param user The address of the user to update.
    /// @param onPool The new scaled balance on pool of the `user`.
    /// @param inP2P The new scaled balance in peer-to-peer of the `user`.
    /// @param demoting Whether the update is happening during a demoting process or not.
    /// @return The actual new scaled balance on pool and in peer-to-peer of the `user` after accounting for dust.
    function _updateSupplierInDS(address underlying, address user, uint256 onPool, uint256 inP2P, bool demoting)
        internal
        returns (uint256, uint256)
    {
        return _updateInDS(
            _market[underlying].aToken,
            user,
            _marketBalances[underlying].poolSuppliers,
            _marketBalances[underlying].p2pSuppliers,
            onPool,
            inP2P,
            demoting
        );
        // No need to update the user's list of supplied assets,
        // as it cannot be used as collateral and thus there's no need to iterate over it.
    }

    /// @dev Updates a `user`'s borrow position in the data structure.
    /// @param underlying The address of the underlying asset.
    /// @param user The address of the user to update.
    /// @param onPool The new scaled balance on pool of the `user`.
    /// @param inP2P The new scaled balance in peer-to-peer of the `user`.
    /// @param demoting Whether the update is happening during a demoting process or not.
    /// @return The actual new scaled balance on pool and in peer-to-peer of the `user` after accounting for dust.
    function _updateBorrowerInDS(address underlying, address user, uint256 onPool, uint256 inP2P, bool demoting)
        internal
        returns (uint256, uint256)
    {
        (onPool, inP2P) = _updateInDS(
            _market[underlying].variableDebtToken,
            user,
            _marketBalances[underlying].poolBorrowers,
            _marketBalances[underlying].p2pBorrowers,
            onPool,
            inP2P,
            demoting
        );
        if (onPool == 0 && inP2P == 0) _userBorrows[user].remove(underlying);
        else _userBorrows[user].add(underlying);
        return (onPool, inP2P);
    }

    /// @dev Sets globally the pause status to `isPaused` on the `underlying` market.
    function _setPauseStatus(address underlying, bool isPaused) internal {
        Types.Market storage market = _market[underlying];

        market.setIsSupplyPaused(isPaused);
        market.setIsSupplyCollateralPaused(isPaused);
        market.setIsRepayPaused(isPaused);
        market.setIsWithdrawPaused(isPaused);
        market.setIsWithdrawCollateralPaused(isPaused);
        market.setIsLiquidateCollateralPaused(isPaused);
        market.setIsLiquidateBorrowPaused(isPaused);
        if (!market.isDeprecated()) market.setIsBorrowPaused(isPaused);
    }

    /// @dev Updates the indexes of the `underlying` market and returns them.
    function _updateIndexes(address underlying) internal returns (Types.Indexes256 memory indexes) {
        indexes = _computeIndexes(underlying);

        _market[underlying].setIndexes(indexes);
    }

    /// @dev Computes the updated indexes of the `underlying` market and returns them.
    function _computeIndexes(address underlying) internal view returns (Types.Indexes256 memory indexes) {
        Types.Market storage market = _market[underlying];
        Types.Indexes256 memory lastIndexes = market.getIndexes();

        (indexes.supply.poolIndex, indexes.borrow.poolIndex) = _pool.getCurrentPoolIndexes(underlying);

        (indexes.supply.p2pIndex, indexes.borrow.p2pIndex) = InterestRatesLib.computeP2PIndexes(
            Types.IndexesParams({
                lastSupplyIndexes: lastIndexes.supply,
                lastBorrowIndexes: lastIndexes.borrow,
                poolSupplyIndex: indexes.supply.poolIndex,
                poolBorrowIndex: indexes.borrow.poolIndex,
                reserveFactor: market.reserveFactor,
                p2pIndexCursor: market.p2pIndexCursor,
                deltas: market.deltas,
                proportionIdle: market.getProportionIdle()
            })
        );
    }

    /// @dev Returns the `user`'s health factor.
    function _getUserHealthFactor(address user) internal view returns (uint256) {
        Types.LiquidityData memory liquidityData = _liquidityData(user);

        return liquidityData.debt > 0 ? liquidityData.maxDebt.wadDiv(liquidityData.debt) : type(uint256).max;
    }

    /// @dev Returns data relative to the given asset and its configuration, according to a given oracle.
    /// @return Whether the given asset is part of Morpho's e-mode category.
    /// @return The asset's price or the price of the given e-mode price source if the asset is in the e-mode category, according to the given oracle.
    /// @return The asset's unit.
    function _assetData(
        address asset,
        IAaveOracle oracle,
        DataTypes.ReserveConfigurationMap memory config,
        address priceSource
    ) internal view returns (bool, uint256, uint256) {
        uint256 assetUnit;
        unchecked {
            assetUnit = 10 ** config.getDecimals();
        }

        bool isInEMode = _isInEModeCategory(config);
        if (isInEMode && priceSource != address(0)) {
            uint256 eModePrice = oracle.getAssetPrice(priceSource);

            if (eModePrice != 0) return (isInEMode, eModePrice, assetUnit);
        }

        return (isInEMode, oracle.getAssetPrice(asset), assetUnit);
    }

    /// @dev Returns whether Morpho is in an e-mode category and the given asset configuration is in the same e-mode category.
    function _isInEModeCategory(DataTypes.ReserveConfigurationMap memory config) internal view returns (bool) {
        return _eModeCategoryId != 0 && config.getEModeCategory() == _eModeCategoryId;
    }
}
