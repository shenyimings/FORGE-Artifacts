// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// @title Events
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Library exposing events used in Morpho.
library Events {
    /// @notice Emitted when a supply happens.
    /// @param from The address of the user supplying the funds.
    /// @param onBehalf The address of the user on behalf of which the position is created.
    /// @param underlying The address of the underlying asset supplied.
    /// @param amount The amount of `underlying` asset supplied.
    /// @param scaledOnPool The scaled supply balance on pool of `onBehalf` after the supply.
    /// @param scaledInP2P The scaled supply balance in peer-to-peer of `onBehalf` after the supply.
    event Supplied(
        address indexed from,
        address indexed onBehalf,
        address indexed underlying,
        uint256 amount,
        uint256 scaledOnPool,
        uint256 scaledInP2P
    );

    /// @notice Emitted when a supply collateral happens.
    /// @param from The address of the user supplying the funds.
    /// @param onBehalf The address of the user on behalf of which the position is created.
    /// @param underlying The address of the underlying asset supplied.
    /// @param amount The amount of `underlying` asset supplied.
    /// @param scaledBalance The scaled collateral balance of `onBehalf` after the supply.
    event CollateralSupplied(
        address indexed from,
        address indexed onBehalf,
        address indexed underlying,
        uint256 amount,
        uint256 scaledBalance
    );

    /// @notice Emitted when a borrow happens.
    /// @param caller The address of the caller.
    /// @param onBehalf The address of the user on behalf of which the position is created.
    /// @param receiver The address of the user receiving the funds.
    /// @param underlying The address of the underlying asset borrowed.
    /// @param amount The amount of `underlying` asset borrowed.
    /// @param scaledOnPool The scaled borrow balance on pool of `onBehalf` after the borrow.
    /// @param scaledInP2P The scaled borrow balance in peer-to-peer of `onBehalf` after the borrow.
    event Borrowed(
        address caller,
        address indexed onBehalf,
        address indexed receiver,
        address indexed underlying,
        uint256 amount,
        uint256 scaledOnPool,
        uint256 scaledInP2P
    );

    /// @notice Emitted when a repay happens.
    /// @param repayer The address of the user repaying the debt.
    /// @param onBehalf The address of the user on behalf of which the position is modified.
    /// @param underlying The address of the underlying asset repaid.
    /// @param amount The amount of `underlying` asset repaid.
    /// @param scaledOnPool The scaled borrow balance on pool of `onBehalf` after the repay.
    /// @param scaledInP2P The scaled borrow balance in peer-to-peer of `onBehalf` after the repay.
    event Repaid(
        address indexed repayer,
        address indexed onBehalf,
        address indexed underlying,
        uint256 amount,
        uint256 scaledOnPool,
        uint256 scaledInP2P
    );

    /// @notice Emitted when a withdraw happens.
    /// @param caller The address of the caller.
    /// @param onBehalf The address of the user on behalf of which the position is modified.
    /// @param receiver The address of the user receiving the funds.
    /// @param underlying The address of the underlying asset withdrawn.
    /// @param amount The amount of `underlying` asset withdrawn.
    /// @param scaledOnPool The scaled supply balance on pool of `onBehalf` after the withdraw.
    /// @param scaledInP2P The scaled supply balance in peer-to-peer of `onBehalf` after the withdraw.
    event Withdrawn(
        address caller,
        address indexed onBehalf,
        address indexed receiver,
        address indexed underlying,
        uint256 amount,
        uint256 scaledOnPool,
        uint256 scaledInP2P
    );

    /// @notice Emitted when a withdraw collateral happens.
    /// @param caller The address of the caller.
    /// @param onBehalf The address of the user on behalf of which the position is modified.
    /// @param receiver The address of the user receiving the funds.
    /// @param underlying The address of the underlying asset withdrawn.
    /// @param amount The amount of `underlying` asset withdrawn.
    /// @param scaledBalance The scaled collateral balance of `onBehalf` after the withdraw.
    event CollateralWithdrawn(
        address caller,
        address indexed onBehalf,
        address indexed receiver,
        address indexed underlying,
        uint256 amount,
        uint256 scaledBalance
    );

    /// @notice Emitted when a liquidate happens.
    /// @param liquidator The address of the liquidator.
    /// @param borrower The address of the borrower that was liquidated.
    /// @param underlyingBorrowed The address of the underlying asset borrowed being repaid.
    /// @param amountLiquidated The amount of `underlyingBorrowed` repaid.
    /// @param underlyingCollateral The address of the collateral underlying seized.
    /// @param amountSeized The amount of `underlyingCollateral` seized.
    event Liquidated(
        address indexed liquidator,
        address indexed borrower,
        address indexed underlyingBorrowed,
        uint256 amountLiquidated,
        address underlyingCollateral,
        uint256 amountSeized
    );

    /// @notice Emitted when a `manager` is approved or unapproved to act on behalf of a `delegator`.
    event ManagerApproval(address indexed delegator, address indexed manager, bool isAllowed);

    /// @notice Emitted when a supply position is updated.
    /// @param user The address of the user.
    /// @param underlying The address of the underlying asset.
    /// @param scaledOnPool The scaled supply balance on pool of `user` after the update.
    /// @param scaledInP2P The scaled supply balance in peer-to-peer of `user` after the update.
    event SupplyPositionUpdated(
        address indexed user, address indexed underlying, uint256 scaledOnPool, uint256 scaledInP2P
    );

    /// @notice Emitted when a borrow position is updated.
    /// @param user The address of the user.
    /// @param underlying The address of the underlying asset.
    /// @param scaledOnPool The scaled borrow balance on pool of `user` after the update.
    /// @param scaledInP2P The scaled borrow balance in peer-to-peer of `user` after the update.
    event BorrowPositionUpdated(
        address indexed user, address indexed underlying, uint256 scaledOnPool, uint256 scaledInP2P
    );

    /// @notice Emitted when a peer-to-peer supply delta is updated.
    /// @param underlying The address of the underlying asset.
    /// @param scaledDelta The scaled supply delta of `underlying` asset.
    event P2PSupplyDeltaUpdated(address indexed underlying, uint256 scaledDelta);

    /// @notice Emitted when a peer-to-peer borrow delta is updated.
    /// @param underlying The address of the underlying asset.
    /// @param scaledDelta The scaled borrow delta of `underlying` asset.
    event P2PBorrowDeltaUpdated(address indexed underlying, uint256 scaledDelta);

    /// @notice Emitted when the peer-to-peer total amounts are updated.
    /// @param underlying The address of the underlying asset.
    /// @param scaledTotalSupplyP2P The scaled total supply of `underlying` asset in peer-to-peer.
    /// @param scaledTotalBorrowP2P The scaled total borrow of `underlying` asset in peer-to-peer.
    event P2PTotalsUpdated(address indexed underlying, uint256 scaledTotalSupplyP2P, uint256 scaledTotalBorrowP2P);

    /// @notice Emitted when a rewards are claimed.
    /// @param claimer The address of the user claiming the rewards.
    /// @param onBehalf The address of the user on behalf of which the rewards are claimed.
    /// @param rewardToken The address of the reward token claimed.
    /// @param amountClaimed The amount of `rewardToken` claimed.
    event RewardsClaimed(
        address indexed claimer, address indexed onBehalf, address indexed rewardToken, uint256 amountClaimed
    );

    /// @notice Emitted when the collateral status of the `underlying` market is set to `isCollateral`.
    event IsCollateralSet(address indexed underlying, bool isCollateral);

    /// @notice Emitted when the claim rewards status is set to `isPaused`.
    event IsClaimRewardsPausedSet(bool isPaused);

    /// @notice Emitted when the supply pause status of the `underlying` market is set to `isPaused`.
    event IsSupplyPausedSet(address indexed underlying, bool isPaused);

    /// @notice Emitted when the supply collateral pause status of the `underlying` market is set to `isPaused`.
    event IsSupplyCollateralPausedSet(address indexed underlying, bool isPaused);

    /// @notice Emitted when the borrow pause status of the `underlying` market is set to `isPaused`.
    event IsBorrowPausedSet(address indexed underlying, bool isPaused);

    /// @notice Emitted when the withdraw pause status of the `underlying` market is set to `isPaused`.
    event IsWithdrawPausedSet(address indexed underlying, bool isPaused);

    /// @notice Emitted when the withdraw collateral pause status of the `underlying` market is set to `isPaused`.
    event IsWithdrawCollateralPausedSet(address indexed underlying, bool isPaused);

    /// @notice Emitted when the repay pause status of the `underlying` market is set to `isPaused`.
    event IsRepayPausedSet(address indexed underlying, bool isPaused);

    /// @notice Emitted when the liquidate collateral pause status of the `underlying` market is set to `isPaused`.
    event IsLiquidateCollateralPausedSet(address indexed underlying, bool isPaused);

    /// @notice Emitted when the liquidate borrow pause status of the `underlying` market is set to `isPaused`.
    event IsLiquidateBorrowPausedSet(address indexed underlying, bool isPaused);

    /// @notice Emitted when an `_increaseP2PDeltas` is triggered.
    /// @param underlying The address of the underlying asset.
    /// @param amount The amount of the increases in `underlying` asset.
    event P2PDeltasIncreased(address indexed underlying, uint256 amount);

    /// @notice Emitted when a new market is created.
    /// @param underlying The address of the underlying asset of the new market.
    event MarketCreated(address indexed underlying);

    /// @notice Emitted when the default iterations are set.
    /// @param repay The default number of repay iterations.
    /// @param withdraw The default number of withdraw iterations.
    event DefaultIterationsSet(uint128 repay, uint128 withdraw);

    /// @notice Emitted when the positions manager is set.
    /// @param positionsManager The address of the positions manager.
    event PositionsManagerSet(address indexed positionsManager);

    /// @notice Emitted when the rewards manager is set.
    /// @param rewardsManager The address of the rewards manager.
    event RewardsManagerSet(address indexed rewardsManager);

    /// @notice Emitted when the treasury vault is set.
    /// @param treasuryVault The address of the treasury vault.
    event TreasuryVaultSet(address indexed treasuryVault);

    /// @notice Emitted when the reserve factor is set.
    /// @param underlying The address of the underlying asset.
    /// @param reserveFactor The reserve factor for this `underlying` asset.
    event ReserveFactorSet(address indexed underlying, uint16 reserveFactor);

    /// @notice Emitted when the peer-to-peer index cursor is set.
    /// @param underlying The address of the underlying asset.
    /// @param p2pIndexCursor The peer-to-peer index cursor for this `underlying` asset.
    event P2PIndexCursorSet(address indexed underlying, uint16 p2pIndexCursor);

    /// @notice Emitted when the peer-to-peer disabled status is set.
    /// @param underlying The address of the underlying asset.
    /// @param isP2PDisabled The peer-to-peer disabled status for this `underlying` asset.
    event IsP2PDisabledSet(address indexed underlying, bool isP2PDisabled);

    /// @notice Emitted when the deprecation status is set.
    /// @param underlying The address of the underlying asset.
    /// @param isDeprecated The deprecation status for this `underlying` asset.
    event IsDeprecatedSet(address indexed underlying, bool isDeprecated);

    /// @notice Emitted when the indexes are updated.
    /// @param underlying The address of the underlying asset.
    /// @param poolSupplyIndex The new pool supply index.
    /// @param p2pSupplyIndex The new peer-to-peer supply index.
    /// @param poolBorrowIndex The new pool borrow index.
    /// @param p2pBorrowIndex The new peer-to-peer borrow index.
    event IndexesUpdated(
        address indexed underlying,
        uint256 poolSupplyIndex,
        uint256 p2pSupplyIndex,
        uint256 poolBorrowIndex,
        uint256 p2pBorrowIndex
    );

    /// @notice Emitted when the idle supply is updated.
    /// @param underlying The address of the underlying asset.
    /// @param idleSupply The new idle supply.
    event IdleSupplyUpdated(address indexed underlying, uint256 idleSupply);

    /// @notice Emitted when the reserve fee is claimed.
    /// @param underlying The address of the underlying asset.
    /// @param claimed The amount of the claimed reserve fee.
    event ReserveFeeClaimed(address indexed underlying, uint256 claimed);

    /// @notice Emitted when a user nonce is incremented.
    /// @param caller The address of the caller.
    /// @param signatory The address of the signatory.
    /// @param usedNonce The used nonce.
    event UserNonceIncremented(address indexed caller, address indexed signatory, uint256 usedNonce);
}
