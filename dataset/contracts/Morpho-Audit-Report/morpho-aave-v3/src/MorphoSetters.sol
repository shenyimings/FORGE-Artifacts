// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorphoSetters} from "./interfaces/IMorpho.sol";
import {IRewardsManager} from "./interfaces/IRewardsManager.sol";

import {Types} from "./libraries/Types.sol";
import {Events} from "./libraries/Events.sol";
import {Errors} from "./libraries/Errors.sol";
import {MarketLib} from "./libraries/MarketLib.sol";

import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {UserConfiguration} from "@aave-v3-core/protocol/libraries/configuration/UserConfiguration.sol";

import {MorphoInternal} from "./MorphoInternal.sol";

/// @title MorphoSetters
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Abstract contract exposing all setters and governance-related functions.
abstract contract MorphoSetters is IMorphoSetters, MorphoInternal {
    using MarketLib for Types.Market;

    using UserConfiguration for DataTypes.UserConfigurationMap;

    /* MODIFIERS */

    /// @notice Prevents to update a market not created yet.
    /// @param underlying The address of the underlying market.
    modifier isMarketCreated(address underlying) {
        if (!_market[underlying].isCreated()) revert Errors.MarketNotCreated();
        _;
    }

    /* GOVERNANCE UTILS */

    /// @notice Creates a new market for the `underlying` token with a given `reserveFactor` (in bps) and a given `p2pIndexCursor` (in bps).
    function createMarket(address underlying, uint16 reserveFactor, uint16 p2pIndexCursor) external onlyOwner {
        _createMarket(underlying, reserveFactor, p2pIndexCursor);
    }

    /// @notice Claims the fee for the `underlyings` and send it to the `_treasuryVault`.
    /// @dev Claiming on a market where there are some rewards might steal users' rewards.
    function claimToTreasury(address[] calldata underlyings, uint256[] calldata amounts) external onlyOwner {
        _claimToTreasury(underlyings, amounts);
    }

    /// @notice Increases the peer-to-peer delta of `amount` on the `underlying` market.
    function increaseP2PDeltas(address underlying, uint256 amount) external onlyOwner isMarketCreated(underlying) {
        _increaseP2PDeltas(underlying, amount);
    }

    /* SETTERS */

    /// @notice Sets `_defaultIterations` to `defaultIterations`.
    function setDefaultIterations(Types.Iterations calldata defaultIterations) external onlyOwner {
        _defaultIterations = defaultIterations;
        emit Events.DefaultIterationsSet(defaultIterations.repay, defaultIterations.withdraw);
    }

    /// @notice Sets `_positionsManager` to `positionsManager`.
    function setPositionsManager(address positionsManager) external onlyOwner {
        if (positionsManager == address(0)) revert Errors.AddressIsZero();
        _positionsManager = positionsManager;
        emit Events.PositionsManagerSet(positionsManager);
    }

    /// @notice Sets `_rewardsManager` to `rewardsManager`.
    /// @dev Note that it is possible to set the address zero. In this case, the pool rewards are not accounted.
    function setRewardsManager(address rewardsManager) external onlyOwner {
        _rewardsManager = IRewardsManager(rewardsManager);
        emit Events.RewardsManagerSet(rewardsManager);
    }

    /// @notice Sets `_treasuryVault` to `treasuryVault`.
    /// @dev Note that it is possible to set the address zero. In this case, it is not possible to claim the fee.
    function setTreasuryVault(address treasuryVault) external onlyOwner {
        _treasuryVault = treasuryVault;
        emit Events.TreasuryVaultSet(treasuryVault);
    }

    /// @notice Sets the `underlying` asset as `isCollateral` on the pool.
    /// @dev The following invariant must hold: is collateral on Morpho => is collateral on pool.
    /// @dev Note that it is possible to set an asset as non-collateral even if the market is not created yet on Morpho.
    ///      This is needed because an aToken with LTV = 0 can be sent to Morpho and would be set as collateral by default, thus blocking withdrawals from the pool.
    ///      However, it's not possible to set an asset as collateral on pool while the market is not created on Morpho.
    function setAssetIsCollateralOnPool(address underlying, bool isCollateral) external onlyOwner {
        Types.Market storage market = _market[underlying];
        if (isCollateral && !market.isCreated()) revert Errors.SetAsCollateralOnPoolButMarketNotCreated();
        if (market.isCollateral) revert Errors.AssetIsCollateralOnMorpho();

        _pool.setUserUseReserveAsCollateral(underlying, isCollateral);
    }

    /// @notice Sets the `underlying` asset as `isCollateral` on Morpho.
    /// @dev The following invariant must hold: is collateral on Morpho => is collateral on pool.
    function setAssetIsCollateral(address underlying, bool isCollateral)
        external
        onlyOwner
        isMarketCreated(underlying)
    {
        if (!_pool.getUserConfiguration(address(this)).isUsingAsCollateral(_pool.getReserveData(underlying).id)) {
            revert Errors.AssetNotCollateralOnPool();
        }

        _market[underlying].setAssetIsCollateral(isCollateral);
    }

    /// @notice Sets the `underlying`'s reserve factor to `newReserveFactor` (in bps).
    function setReserveFactor(address underlying, uint16 newReserveFactor)
        external
        onlyOwner
        isMarketCreated(underlying)
    {
        _updateIndexes(underlying);
        _market[underlying].setReserveFactor(newReserveFactor);
    }

    /// @notice Sets the `underlying`'s peer-to-peer index cursor to `p2pIndexCursor` (in bps).
    function setP2PIndexCursor(address underlying, uint16 p2pIndexCursor)
        external
        onlyOwner
        isMarketCreated(underlying)
    {
        _updateIndexes(underlying);
        _market[underlying].setP2PIndexCursor(p2pIndexCursor);
    }

    /// @notice Sets the claim rewards pause status to `isPaused`.
    function setIsClaimRewardsPaused(bool isPaused) external onlyOwner {
        _isClaimRewardsPaused = isPaused;
        emit Events.IsClaimRewardsPausedSet(isPaused);
    }

    /// @notice Sets the supply pause status to `isPaused` on the `underlying` market.
    function setIsSupplyPaused(address underlying, bool isPaused) external onlyOwner isMarketCreated(underlying) {
        _market[underlying].setIsSupplyPaused(isPaused);
    }

    /// @notice Sets the supply collateral pause status to `isPaused` on the `underlying` market.
    function setIsSupplyCollateralPaused(address underlying, bool isPaused)
        external
        onlyOwner
        isMarketCreated(underlying)
    {
        _market[underlying].setIsSupplyCollateralPaused(isPaused);
    }

    /// @notice Sets the borrow pause status to `isPaused` on the `underlying` market.
    function setIsBorrowPaused(address underlying, bool isPaused) external onlyOwner isMarketCreated(underlying) {
        Types.Market storage market = _market[underlying];
        if (!isPaused && market.isDeprecated()) revert Errors.MarketIsDeprecated();

        market.setIsBorrowPaused(isPaused);
    }

    /// @notice Sets the repay pause status to `isPaused` on the `underlying` market.
    function setIsRepayPaused(address underlying, bool isPaused) external onlyOwner isMarketCreated(underlying) {
        _market[underlying].setIsRepayPaused(isPaused);
    }

    /// @notice Sets the withdraw pause status to `isPaused` on the `underlying` market.
    function setIsWithdrawPaused(address underlying, bool isPaused) external onlyOwner isMarketCreated(underlying) {
        _market[underlying].setIsWithdrawPaused(isPaused);
    }

    /// @notice Sets the withdraw collateral pause status to `isPaused` on the `underlying` market.
    function setIsWithdrawCollateralPaused(address underlying, bool isPaused)
        external
        onlyOwner
        isMarketCreated(underlying)
    {
        _market[underlying].setIsWithdrawCollateralPaused(isPaused);
    }

    /// @notice Sets the liquidate collateral pause status to `isPaused` on the `underlying` market.
    function setIsLiquidateCollateralPaused(address underlying, bool isPaused)
        external
        onlyOwner
        isMarketCreated(underlying)
    {
        _market[underlying].setIsLiquidateCollateralPaused(isPaused);
    }

    /// @notice Sets the liquidate borrow pause status to `isPaused` on the `underlying` market.
    function setIsLiquidateBorrowPaused(address underlying, bool isPaused)
        external
        onlyOwner
        isMarketCreated(underlying)
    {
        _market[underlying].setIsLiquidateBorrowPaused(isPaused);
    }

    /// @notice Sets globally the pause status to `isPaused` on the `underlying` market.
    function setIsPaused(address underlying, bool isPaused) external onlyOwner isMarketCreated(underlying) {
        _setPauseStatus(underlying, isPaused);
    }

    /// @notice Sets the global pause status to `isPaused` on all markets.
    function setIsPausedForAllMarkets(bool isPaused) external onlyOwner {
        uint256 marketsCreatedLength = _marketsCreated.length;
        for (uint256 i; i < marketsCreatedLength; ++i) {
            _setPauseStatus(_marketsCreated[i], isPaused);
        }
    }

    /// @notice Sets the peer-to-peer disable status to `isP2PDisabled` on the `underlying` market.
    function setIsP2PDisabled(address underlying, bool isP2PDisabled) external onlyOwner isMarketCreated(underlying) {
        _market[underlying].setIsP2PDisabled(isP2PDisabled);
    }

    /// @notice Sets the deprecation status to `isDeprecated` on the `underlying` market.
    function setIsDeprecated(address underlying, bool isDeprecated) external onlyOwner isMarketCreated(underlying) {
        Types.Market storage market = _market[underlying];
        if (!market.isBorrowPaused()) revert Errors.BorrowNotPaused();

        market.setIsDeprecated(isDeprecated);
    }
}
