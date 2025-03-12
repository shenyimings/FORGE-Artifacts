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

import { LibReentrancyGuard } from "../libraries/LibReentrancyGuard.sol";
import { LibPoolV1 } from "../libraries/LibPoolV1.sol";
import { LibPoolConfigV1 } from "../libraries/LibPoolConfigV1.sol";

import { PerpTradeFacetInterface } from "../interfaces/PerpTradeFacetInterface.sol";
import { GetterFacetInterface } from "../interfaces/GetterFacetInterface.sol";
import { FundingRateFacetInterface } from "../interfaces/FundingRateFacetInterface.sol";

contract PerpTradeFacet is PerpTradeFacetInterface {
  error PerpTradeFacet_BadCollateralDelta();
  error PerpTradeFacet_BadLiquidator();
  error PerpTradeFacet_BadToken();
  error PerpTradeFacet_BadPositionSize();
  error PerpTradeFacet_BadSizeDelta();
  error PerpTradeFacet_CollateralNotCoverFee();
  error PerpTradeFacet_CollateralTokenIsStable();
  error PerpTradeFacet_CollateralTokenNotStable();
  error PerpTradeFacet_FeeExceedCollateral();
  error PerpTradeFacet_IndexTokenIsStable();
  error PerpTradeFacet_IndexTokenNotShortable();
  error PerpTradeFacet_LeverageDisabled();
  error PerpTradeFacet_LiquidationFeeExceedCollateral();
  error PerpTradeFacet_LossesExceedCollateral();
  error PerpTradeFacet_MaxLeverageExceed();
  error PerpTradeFacet_SizeSmallerThanCollateral();
  error PerpTradeFacet_TokenMisMatch();
  error PerpTradeFacet_BadPositionState();

  uint256 internal constant BPS = 10000;

  event ClosePosition(
    bytes32 posId,
    uint256 size,
    uint256 collateral,
    uint256 averagePrice,
    uint256 entryBorrowingRate,
    uint256 reserveAmount,
    int256 realisedPnL,
    int256 entryFundingRate,
    uint256 openInterest
  );
  event CollectPositionFee(
    address account,
    address token,
    uint256 feeUsd,
    uint256 feeTokens
  );
  event CollectBorrowingFee(
    address account,
    address token,
    uint256 feeUsd,
    uint256 feeTokens
  );
  event CollectFundingFee(
    address account,
    address token,
    int256 feeUsd,
    uint256 feeTokens
  );
  event DecreasePosition(
    bytes32 posId,
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong,
    uint256 price,
    uint256 feeUsd
  );
  event IncreasePosition(
    bytes32 posId,
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 collateralDeltaUsd,
    uint256 sizeDelta,
    bool isLong,
    uint256 price,
    uint256 feeUsd
  );
  event LiquidatePosition(
    bytes32 posId,
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    bool isLong,
    uint256 size,
    uint256 collateral,
    uint256 reserveAmount,
    int256 realisedPnl,
    uint256 markPrice
  );
  event UpdatePnL(bytes32 positionId, bool isProfit, uint256 delta);
  event UpdatePosition(
    bytes32 positionId,
    uint256 size,
    uint256 collateral,
    uint256 averagePrice,
    uint256 entryBorrowingRate,
    uint256 reserveAmount,
    int256 realizedPnl,
    uint256 price,
    int256 entryFundingRate,
    int256 fundingFeeDebt,
    uint256 openInterest
  );

  modifier allowed(address account) {
    LibPoolV1.allowed(account);
    _;
  }

  modifier nonReentrant() {
    LibReentrancyGuard.lock();
    _;
    LibReentrancyGuard.unlock();
  }

  struct CheckLiquidationLocalVars {
    bool isProfit;
    uint256 delta;
    int256 fundingFee;
    uint256 borrowingFee;
    uint256 positionFee;
    uint256 marginFee;
    uint256 remainingCollateral;
  }

  function checkLiquidation(
    address account,
    address collateralToken,
    address indexToken,
    bool isLong,
    bool isRevertOnError
  )
    public
    view
    returns (
      LiquidationState,
      uint256,
      uint256,
      int256
    )
  {
    CheckLiquidationLocalVars memory vars;

    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    LibPoolV1.Position memory position = ds.positions[
      LibPoolV1.getPositionId(account, collateralToken, indexToken, isLong)
    ];

    // Negative fundingFee means profits to the position
    (vars.isProfit, vars.delta, vars.fundingFee) = GetterFacetInterface(
      address(this)
    ).getDelta(
        indexToken,
        position.size,
        position.averagePrice,
        isLong,
        position.lastIncreasedTime,
        position.entryFundingRate,
        position.fundingFeeDebt
      );
    vars.borrowingFee = GetterFacetInterface(address(this)).getBorrowingFee(
      account,
      collateralToken,
      indexToken,
      isLong,
      position.size,
      position.entryBorrowingRate
    );
    vars.positionFee = GetterFacetInterface(address(this)).getPositionFee(
      account,
      collateralToken,
      indexToken,
      isLong,
      position.size
    );
    vars.marginFee = vars.borrowingFee + vars.positionFee;

    if (!vars.isProfit && position.collateral < vars.delta) {
      if (isRevertOnError) revert PerpTradeFacet_LossesExceedCollateral();
      return (
        LiquidationState.LIQUIDATE,
        vars.borrowingFee,
        vars.positionFee,
        vars.fundingFee
      );
    }

    uint256 remainingCollateral = position.collateral;
    if (!vars.isProfit) {
      remainingCollateral -= vars.delta;
    }

    if (remainingCollateral < vars.marginFee) {
      if (isRevertOnError) revert PerpTradeFacet_FeeExceedCollateral();
      // Cap the fee to the remainingCollateral.
      return (
        LiquidationState.LIQUIDATE,
        0,
        remainingCollateral,
        vars.fundingFee
      );
    }

    if (
      remainingCollateral < vars.marginFee + LibPoolConfigV1.liquidationFeeUsd()
    ) {
      if (isRevertOnError)
        revert PerpTradeFacet_LiquidationFeeExceedCollateral();
      // Cap the fee to the margin fee
      return (
        LiquidationState.LIQUIDATE,
        vars.borrowingFee,
        vars.positionFee,
        vars.fundingFee
      );
    }

    if (
      remainingCollateral * LibPoolConfigV1.maxLeverage() < position.size * BPS
    ) {
      if (isRevertOnError) revert PerpTradeFacet_MaxLeverageExceed();
      return (
        LiquidationState.SOFT_LIQUIDATE,
        vars.borrowingFee,
        vars.positionFee,
        vars.fundingFee
      );
    }

    return (
      LiquidationState.HEALTHY,
      vars.borrowingFee,
      vars.positionFee,
      vars.fundingFee
    );
  }

  function _checkPosition(uint256 size, uint256 collateral) internal pure {
    if (size == 0) {
      if (collateral != 0) revert PerpTradeFacet_SizeSmallerThanCollateral();
      return;
    }
    if (size < collateral) revert PerpTradeFacet_SizeSmallerThanCollateral();
  }

  function _checkTokenInputs(
    address collateralToken,
    address indexToken,
    bool isLong
  ) internal view {
    // Load PoolConfigV1 diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigV1ds = LibPoolConfigV1.poolConfigV1DiamondStorage();

    if (isLong) {
      if (collateralToken != indexToken) revert PerpTradeFacet_TokenMisMatch();
      if (!poolConfigV1ds.tokenMetas[collateralToken].accept)
        revert PerpTradeFacet_BadToken();
      if (poolConfigV1ds.tokenMetas[collateralToken].isStable)
        revert PerpTradeFacet_CollateralTokenIsStable();
      return;
    }

    if (!poolConfigV1ds.tokenMetas[collateralToken].accept)
      revert PerpTradeFacet_BadToken();
    if (!poolConfigV1ds.tokenMetas[collateralToken].isStable)
      revert PerpTradeFacet_CollateralTokenNotStable();
    if (poolConfigV1ds.tokenMetas[indexToken].isStable)
      revert PerpTradeFacet_IndexTokenIsStable();
    if (!poolConfigV1ds.tokenMetas[indexToken].isShortable)
      revert PerpTradeFacet_IndexTokenNotShortable();
  }

  function _collectMarginFee(
    address primaryAccount,
    address account,
    address collateralToken,
    address indexToken,
    bool isLong,
    uint256 sizeDelta,
    uint256 size,
    uint256 entryBorrowingRate
  ) internal returns (uint256) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    uint256 feeUsd = GetterFacetInterface(address(this)).getPositionFee(
      account,
      collateralToken,
      indexToken,
      isLong,
      sizeDelta
    );
    emit CollectPositionFee(
      primaryAccount,
      collateralToken,
      feeUsd,
      LibPoolV1.convertUsde30ToTokens(collateralToken, feeUsd, true)
    );

    uint256 borrowingFeeUsd = GetterFacetInterface(address(this))
      .getBorrowingFee(
        account,
        collateralToken,
        indexToken,
        isLong,
        size,
        entryBorrowingRate
      );

    emit CollectBorrowingFee(
      primaryAccount,
      collateralToken,
      borrowingFeeUsd,
      LibPoolV1.convertUsde30ToTokens(collateralToken, borrowingFeeUsd, true)
    );

    feeUsd += borrowingFeeUsd;

    uint256 feeTokens = LibPoolV1.convertUsde30ToTokens(
      collateralToken,
      feeUsd,
      true
    );
    ds.feeReserveOf[collateralToken] += feeTokens;

    return feeUsd;
  }

  struct IncreasePositionLocalVars {
    address subAccount;
    bytes32 posId;
    uint256 price;
    uint256 feeUsd;
    uint256 collateralDelta;
    uint256 collateralDeltaUsd;
    uint256 reserveDelta;
    uint256 openInterestDelta;
  }

  /// @notice Increase leverage position size.
  /// @param primaryAccount The account that owns the position.
  /// @param subAccountId The sub account ID of the given account.
  /// @param collateralToken The collateral token.
  /// @param indexToken The index token.
  /// @param sizeDelta The size delta in USD units with 1e30 precision.
  /// @param isLong The exposure that the position is in. Either Long or Short.
  function increasePosition(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 sizeDelta,
    bool isLong
  ) external nonReentrant allowed(primaryAccount) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    if (!LibPoolConfigV1.isLeverageEnable())
      revert PerpTradeFacet_LeverageDisabled();
    _checkTokenInputs(collateralToken, indexToken, isLong);

    FundingRateFacetInterface(address(this)).updateFundingRate(
      collateralToken,
      indexToken
    );

    IncreasePositionLocalVars memory vars;

    vars.subAccount = LibPoolV1.getSubAccount(primaryAccount, subAccountId);

    vars.posId = LibPoolV1.getPositionId(
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong
    );
    LibPoolV1.Position storage position = ds.positions[vars.posId];

    vars.price = isLong
      ? ds.oracle.getMaxPrice(indexToken)
      : ds.oracle.getMinPrice(indexToken);

    if (position.size == 0) {
      // If position size = 0, then it is a new position.
      // So make average price to equal to price.
      // And assign the primary account
      position.averagePrice = vars.price;
      position.primaryAccount = primaryAccount;
    }

    if (position.size > 0 && sizeDelta > 0) {
      // If position size > 0, then position is existed.
      // Need to calculate the next average price.
      position.averagePrice = GetterFacetInterface(address(this))
        .getPositionNextAveragePrice(
          indexToken,
          position.size,
          position.averagePrice,
          isLong,
          vars.price,
          sizeDelta,
          position.lastIncreasedTime
        );
    }

    vars.feeUsd = _collectMarginFee(
      primaryAccount,
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong,
      sizeDelta,
      position.size,
      position.entryBorrowingRate
    );
    vars.collateralDelta = LibPoolV1.pullTokens(collateralToken);
    vars.collateralDeltaUsd = LibPoolV1.convertTokensToUsde30(
      collateralToken,
      vars.collateralDelta,
      false
    );
    position.collateral += vars.collateralDeltaUsd;
    if (position.collateral < vars.feeUsd)
      revert PerpTradeFacet_CollateralNotCoverFee();

    position.collateral -= vars.feeUsd;
    position.entryBorrowingRate = GetterFacetInterface(address(this))
      .getEntryBorrowingRate(collateralToken, indexToken, isLong);
    position.fundingFeeDebt += GetterFacetInterface(address(this))
      .getFundingFee(
        indexToken,
        isLong,
        position.size,
        position.entryFundingRate
      );
    position.entryFundingRate = GetterFacetInterface(address(this))
      .getEntryFundingRate(collateralToken, indexToken, isLong);
    position.size += sizeDelta;
    position.lastIncreasedTime = block.timestamp;

    if (position.size == 0) revert PerpTradeFacet_BadPositionSize();
    _checkPosition(position.size, position.collateral);
    checkLiquidation(
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong,
      true
    );

    // Lock tokens in reserved to pay for profits on this position.
    uint256 reserveDelta = LibPoolV1.convertUsde30ToTokens(
      collateralToken,
      sizeDelta,
      false
    );
    position.reserveAmount += reserveDelta;
    LibPoolV1.increaseReserved(collateralToken, reserveDelta);
    uint256 openInterestDelta = LibPoolV1.convertUsde30ToTokens(
      indexToken,
      sizeDelta,
      true
    );
    position.openInterest += openInterestDelta;
    LibPoolV1.increaseOpenInterest(isLong, indexToken, openInterestDelta);
    // Realize profit/loss result from the farm strategy
    // NOTE: This should be called after pullTokens() so that the profit won't be included in the function
    LibPoolV1.realizedFarmPnL(collateralToken);
    // If indexToken != collateralToken, need to realize indexToken as well
    if (collateralToken != indexToken) LibPoolV1.realizedFarmPnL(indexToken);

    if (isLong) {
      // guaranteedUsd stores the sum of (position.size - position.collateral) for all positions
      // if a fee is charged on the collateral then guaranteedUsd should be increased by that fee amount
      // since (position.size - position.collateral) would have increased by `fee`
      LibPoolV1.increaseGuaranteedUsd(collateralToken, sizeDelta + vars.feeUsd);
      LibPoolV1.decreaseGuaranteedUsd(collateralToken, vars.collateralDeltaUsd);

      // treat the deposited collateral as part of the pool
      LibPoolV1.increasePoolLiquidity(collateralToken, vars.collateralDelta);

      // fees need to be deducted from the pool since fees are deducted from position.collateral
      // and collateral is treated as part of the pool
      LibPoolV1.decreasePoolLiquidity(
        collateralToken,
        LibPoolV1.convertUsde30ToTokens(collateralToken, vars.feeUsd, true)
      );
    } else {
      if (ds.shortSizeOf[indexToken] == 0)
        ds.shortAveragePriceOf[indexToken] = vars.price;
      else {
        ds.shortAveragePriceOf[indexToken] = GetterFacetInterface(address(this))
          .getNextShortAveragePriceWithRealizedPnl(
            indexToken,
            vars.price,
            int256(sizeDelta),
            0
          );
      }

      LibPoolV1.increaseShortSize(indexToken, sizeDelta);
    }

    emit IncreasePosition(
      vars.posId,
      primaryAccount,
      subAccountId,
      collateralToken,
      indexToken,
      vars.collateralDeltaUsd,
      sizeDelta,
      isLong,
      vars.price,
      vars.feeUsd
    );
    emit UpdatePosition(
      vars.posId,
      position.size,
      position.collateral,
      position.averagePrice,
      position.entryBorrowingRate,
      position.reserveAmount,
      position.realizedPnl,
      vars.price,
      position.entryFundingRate,
      position.fundingFeeDebt,
      position.openInterest
    );
  }

  struct DecreasePositionLocalVars {
    address subAccount;
    bytes32 posId;
    uint256 collateral;
    uint256 reserveDelta;
    uint256 usdOut;
    uint256 usdOutAfterFee;
    uint256 price;
    uint256 openInterestDelta;
  }

  function decreasePosition(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong,
    address receiver
  ) external nonReentrant allowed(primaryAccount) returns (uint256) {
    // Realize profit/loss result from the farm strategy
    LibPoolV1.realizedFarmPnL(collateralToken);
    // If indexToken != collateralToken, need to realize indexToken as well
    if (collateralToken != indexToken) LibPoolV1.realizedFarmPnL(indexToken);

    uint256 amountOut = _decreasePosition(
      primaryAccount,
      subAccountId,
      collateralToken,
      indexToken,
      collateralDelta,
      sizeDelta,
      isLong,
      receiver
    );

    return amountOut;
  }

  /// @notice Decrease leverage position size.
  function _decreasePosition(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong,
    address receiver
  ) internal returns (uint256) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    FundingRateFacetInterface(address(this)).updateFundingRate(
      collateralToken,
      indexToken
    );

    DecreasePositionLocalVars memory vars;

    vars.subAccount = GetterFacetInterface(address(this)).getSubAccount(
      primaryAccount,
      subAccountId
    );

    vars.posId = LibPoolV1.getPositionId(
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong
    );
    LibPoolV1.Position storage position = ds.positions[vars.posId];
    if (position.size == 0) revert PerpTradeFacet_BadPositionSize();
    if (sizeDelta > position.size) revert PerpTradeFacet_BadSizeDelta();
    if (collateralDelta > position.collateral)
      revert PerpTradeFacet_BadCollateralDelta();

    // Reduce position's reserveAmount proportionally to sizeDelta and positionSize.
    // Then decrease reserved token in the pool as well.
    vars.reserveDelta = (position.reserveAmount * sizeDelta) / position.size;
    position.reserveAmount -= vars.reserveDelta;
    LibPoolV1.decreaseReserved(collateralToken, vars.reserveDelta);
    vars.openInterestDelta =
      (position.openInterest * sizeDelta) /
      position.size;
    position.openInterest -= vars.openInterestDelta;
    LibPoolV1.decreaseOpenInterest(isLong, indexToken, vars.openInterestDelta);

    // Preload position's collateral here as _reduceCollateral will alter it
    vars.collateral = position.collateral;

    // Perform the actual reduce collateral
    (vars.usdOut, vars.usdOutAfterFee) = _reduceCollateral(
      primaryAccount,
      vars.subAccount,
      collateralToken,
      indexToken,
      collateralDelta,
      sizeDelta,
      isLong
    );

    bool isFullClose = position.size == sizeDelta;
    if (position.size != sizeDelta) {
      // Partially close the position
      position.entryBorrowingRate = GetterFacetInterface(address(this))
        .getEntryBorrowingRate(collateralToken, indexToken, isLong);
      position.entryFundingRate = GetterFacetInterface(address(this))
        .getEntryFundingRate(collateralToken, indexToken, isLong);
      position.size -= sizeDelta;

      _checkPosition(position.size, position.collateral);
      checkLiquidation(
        vars.subAccount,
        collateralToken,
        indexToken,
        isLong,
        true
      );

      if (isLong) {
        // Update guaranteedUsd by increase by delta of collateralBeforeReduce and collateralAfterReduce
        // Then decrease by sizeDelta
        LibPoolV1.increaseGuaranteedUsd(
          collateralToken,
          vars.collateral - position.collateral
        );
        LibPoolV1.decreaseGuaranteedUsd(collateralToken, sizeDelta);
      }

      vars.price = isLong
        ? ds.oracle.getMinPrice(indexToken)
        : ds.oracle.getMaxPrice(indexToken);

      emit DecreasePosition(
        vars.posId,
        primaryAccount,
        subAccountId,
        collateralToken,
        indexToken,
        collateralDelta,
        sizeDelta,
        isLong,
        vars.price,
        vars.usdOut - vars.usdOutAfterFee
      );
      emit UpdatePosition(
        vars.posId,
        position.size,
        position.collateral,
        position.averagePrice,
        position.entryBorrowingRate,
        position.reserveAmount,
        position.realizedPnl,
        vars.price,
        position.entryFundingRate,
        position.fundingFeeDebt,
        position.openInterest
      );
    } else {
      // Close position
      if (isLong) {
        LibPoolV1.increaseGuaranteedUsd(collateralToken, vars.collateral);
        LibPoolV1.decreaseGuaranteedUsd(collateralToken, sizeDelta);
      }

      vars.price = isLong
        ? ds.oracle.getMinPrice(indexToken)
        : ds.oracle.getMaxPrice(indexToken);

      emit DecreasePosition(
        vars.posId,
        primaryAccount,
        subAccountId,
        collateralToken,
        indexToken,
        collateralDelta,
        sizeDelta,
        isLong,
        vars.price,
        vars.usdOut - vars.usdOutAfterFee
      );
      emit ClosePosition(
        vars.posId,
        position.size,
        position.collateral,
        position.averagePrice,
        position.entryBorrowingRate,
        position.reserveAmount,
        position.realizedPnl,
        position.entryFundingRate,
        position.openInterest
      );
    }

    if (!isLong) {
      if (ds.shortSizeOf[indexToken] == 0)
        ds.shortAveragePriceOf[indexToken] = vars.price;
      else {
        (bool isProfit, uint256 pnl) = GetterFacetInterface(address(this))
          .getDeltaWithoutFundingFee(
            indexToken,
            position.size,
            position.averagePrice,
            isLong,
            position.lastIncreasedTime
          );
        uint256 realizedPnl = (pnl * sizeDelta) / position.size;
        ds.shortAveragePriceOf[indexToken] = GetterFacetInterface(address(this))
          .getNextShortAveragePriceWithRealizedPnl(
            indexToken,
            vars.price,
            -int256(sizeDelta),
            isProfit ? int256(realizedPnl) : -int256(realizedPnl)
          );
      }
      LibPoolV1.decreaseShortSize(indexToken, sizeDelta);
    }

    // Remove position if it is fully closed
    if (isFullClose) delete ds.positions[vars.posId];

    if (vars.usdOut > 0) {
      if (isLong)
        LibPoolV1.decreasePoolLiquidity(
          collateralToken,
          LibPoolV1.convertUsde30ToTokens(collateralToken, vars.usdOut, true)
        );
      uint256 amountOutAfterFee = LibPoolV1.convertUsde30ToTokens(
        collateralToken,
        vars.usdOutAfterFee,
        true
      );

      LibPoolV1.tokenOut(collateralToken, receiver, amountOutAfterFee);

      return amountOutAfterFee;
    }

    return 0;
  }

  struct LiquidateLocalVars {
    address subAccount;
    bytes32 posId;
    uint256 marginFee;
    int256 fundingFee;
    uint256 feeTokens;
    uint256 markPrice;
    uint256 remainingCollateral;
    uint256 borrowingFee;
    uint256 positionFee;
    LiquidationState liquidationState;
  }

  function liquidate(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    bool isLong,
    address to
  ) external nonReentrant {
    LiquidateLocalVars memory vars;
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    if (!LibPoolConfigV1.isAllowedLiquidators(msg.sender))
      revert PerpTradeFacet_BadLiquidator();

    // Realize profit/loss result from the farm strategy
    LibPoolV1.realizedFarmPnL(collateralToken);
    // If indexToken != collateralToken, need to realize indexToken as well
    if (collateralToken != indexToken) LibPoolV1.realizedFarmPnL(indexToken);

    FundingRateFacetInterface(address(this)).updateFundingRate(
      collateralToken,
      indexToken
    );

    vars.subAccount = GetterFacetInterface(address(this)).getSubAccount(
      primaryAccount,
      subAccountId
    );

    vars.posId = LibPoolV1.getPositionId(
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong
    );
    LibPoolV1.Position memory position = ds.positions[vars.posId];

    if (position.size == 0) revert PerpTradeFacet_BadPositionSize();

    (
      vars.liquidationState,
      vars.borrowingFee,
      vars.positionFee,
      vars.fundingFee
    ) = checkLiquidation(
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong,
      false
    );
    if (vars.liquidationState == LiquidationState.HEALTHY)
      revert PerpTradeFacet_BadPositionState();
    vars.marginFee = vars.borrowingFee + vars.positionFee;
    if (vars.liquidationState == LiquidationState.SOFT_LIQUIDATE) {
      // Position's leverage is exceeded, but there is enough collateral to soft-liquidate.
      _decreasePosition(
        primaryAccount,
        subAccountId,
        collateralToken,
        indexToken,
        0,
        position.size,
        isLong,
        position.primaryAccount
      );
      return;
    }

    vars.feeTokens = LibPoolV1.convertUsde30ToTokens(
      collateralToken,
      vars.marginFee,
      true
    );
    ds.feeReserveOf[collateralToken] += vars.feeTokens;
    emit CollectPositionFee(
      primaryAccount,
      collateralToken,
      vars.positionFee,
      vars.feeTokens
    );
    emit CollectBorrowingFee(
      primaryAccount,
      collateralToken,
      vars.borrowingFee,
      vars.feeTokens
    );

    // Decreases reserve amount of a collateral token.
    LibPoolV1.decreaseReserved(collateralToken, position.reserveAmount);
    LibPoolV1.decreaseOpenInterest(isLong, indexToken, position.openInterest);
    LibPoolV1.updateFundingFeeAccounting(vars.fundingFee);

    emit CollectFundingFee(
      primaryAccount,
      collateralToken,
      vars.fundingFee,
      LibPoolV1.convertUsde30ToTokens(
        collateralToken,
        vars.fundingFee > 0
          ? uint256(vars.fundingFee)
          : uint256(-vars.fundingFee),
        true
      )
    );

    if (isLong) {
      // If it is long, then decrease guaranteed usd and pool's liquidity
      LibPoolV1.decreaseGuaranteedUsd(
        collateralToken,
        position.size - position.collateral
      );
      LibPoolV1.decreasePoolLiquidity(
        collateralToken,
        LibPoolV1.convertUsde30ToTokens(collateralToken, vars.marginFee, true)
      );
    }

    vars.markPrice = isLong
      ? ds.oracle.getMinPrice(indexToken)
      : ds.oracle.getMaxPrice(indexToken);

    emit LiquidatePosition(
      vars.posId,
      primaryAccount,
      subAccountId,
      collateralToken,
      indexToken,
      isLong,
      position.size,
      position.collateral,
      position.reserveAmount,
      position.realizedPnl,
      vars.markPrice
    );

    if (!isLong && vars.marginFee < position.collateral) {
      uint256 remainingCollateral = position.collateral - vars.marginFee;
      LibPoolV1.increasePoolLiquidity(
        collateralToken,
        LibPoolV1.convertUsde30ToTokens(
          collateralToken,
          remainingCollateral,
          true
        )
      );
    }

    if (!isLong) {
      if (ds.shortSizeOf[indexToken] == 0)
        ds.shortAveragePriceOf[indexToken] = vars.markPrice;
      else {
        (bool isProfit, uint256 realizedPnl) = GetterFacetInterface(
          address(this)
        ).getDeltaWithoutFundingFee(
            indexToken,
            position.size,
            position.averagePrice,
            isLong,
            position.lastIncreasedTime
          );
        ds.shortAveragePriceOf[indexToken] = GetterFacetInterface(address(this))
          .getNextShortAveragePriceWithRealizedPnl(
            indexToken,
            vars.markPrice,
            -int256(position.size),
            isProfit ? int256(realizedPnl) : -int256(realizedPnl)
          );
      }
      LibPoolV1.decreaseShortSize(indexToken, position.size);
    }

    delete ds.positions[vars.posId];

    // Pay liquidation bounty with the pool's liquidity
    LibPoolV1.decreasePoolLiquidity(
      collateralToken,
      LibPoolV1.convertUsde30ToTokens(
        collateralToken,
        LibPoolConfigV1.liquidationFeeUsd(),
        true
      )
    );
    LibPoolV1.tokenOut(
      collateralToken,
      to,
      LibPoolV1.convertUsde30ToTokens(
        collateralToken,
        LibPoolConfigV1.liquidationFeeUsd(),
        true
      )
    );
  }

  struct ReduceCollateralLocalVars {
    uint256 feeUsd;
    uint256 delta;
    uint256 usdOut;
    uint256 usdOutAfterFee;
    bool isProfit;
    int256 fundingFee;
    int256 realizedFundingFee;
  }

  function _reduceCollateral(
    address primaryAccount,
    address account,
    address collateralToken,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong
  ) internal returns (uint256, uint256) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    bytes32 posId = LibPoolV1.getPositionId(
      account,
      collateralToken,
      indexToken,
      isLong
    );
    LibPoolV1.Position storage position = ds.positions[posId];

    ReduceCollateralLocalVars memory vars;

    // Collect margin fee
    vars.feeUsd = _collectMarginFee(
      primaryAccount,
      account,
      collateralToken,
      indexToken,
      isLong,
      sizeDelta,
      position.size,
      position.entryBorrowingRate
    );

    // Calculate position's delta.
    (vars.isProfit, vars.delta, vars.fundingFee) = GetterFacetInterface(
      address(this)
    ).getDelta(
        indexToken,
        position.size,
        position.averagePrice,
        isLong,
        position.lastIncreasedTime,
        position.entryFundingRate,
        position.fundingFeeDebt
      );

    // Adjusting delta to be proportionally to size delta and position size
    vars.delta = (vars.delta * sizeDelta) / position.size;
    vars.realizedFundingFee =
      (vars.fundingFee * int256(sizeDelta)) /
      int256(position.size);
    position.fundingFeeDebt = vars.fundingFee - vars.realizedFundingFee;
    LibPoolV1.updateFundingFeeAccounting(vars.realizedFundingFee);

    emit CollectFundingFee(
      primaryAccount,
      collateralToken,
      vars.realizedFundingFee,
      LibPoolV1.convertUsde30ToTokens(
        collateralToken,
        vars.realizedFundingFee > 0
          ? uint256(vars.realizedFundingFee)
          : uint256(-vars.realizedFundingFee),
        true
      )
    );

    if (vars.isProfit && vars.delta > 0) {
      // Position is profitable. Handle profits here.
      vars.usdOut = vars.delta;

      // realized PnL
      position.realizedPnl += int256(vars.delta);

      if (!isLong)
        // If it is a short position, payout profits from the liquidity.
        LibPoolV1.decreasePoolLiquidity(
          collateralToken,
          LibPoolV1.convertUsde30ToTokens(collateralToken, vars.delta, true)
        );
    }

    if (!vars.isProfit && vars.delta > 0) {
      // Position is not profitable. Handle losses here.

      // Take out collateral
      position.collateral -= vars.delta;

      if (!isLong)
        // If it is a short position, add short losses to pool liquidity.
        LibPoolV1.increasePoolLiquidity(
          collateralToken,
          LibPoolV1.convertUsde30ToTokens(collateralToken, vars.delta, true)
        );

      // realized PnL
      position.realizedPnl -= int256(vars.delta);
    }

    // Reduce position's collateral by collateralDelta
    if (collateralDelta > 0) {
      vars.usdOut += collateralDelta;
      position.collateral -= collateralDelta;
    }

    // If position to be closed, then remove all collateral from it.
    if (position.size == sizeDelta) {
      vars.usdOut += position.collateral;
      position.collateral = 0;
    }

    vars.usdOutAfterFee = vars.usdOut;
    if (vars.usdOut > vars.feeUsd)
      // if usdOut is enough to cover fee, then take it out from usdOut
      vars.usdOutAfterFee -= vars.feeUsd;
    else {
      // take fee from the collateral
      position.collateral -= vars.feeUsd;
      if (isLong) {
        LibPoolV1.decreasePoolLiquidity(
          collateralToken,
          LibPoolV1.convertUsde30ToTokens(collateralToken, vars.feeUsd, true)
        );
      }
    }

    emit UpdatePnL(posId, vars.isProfit, vars.delta);

    return (vars.usdOut, vars.usdOutAfterFee);
  }
}
