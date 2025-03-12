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

import { LibPoolV1 } from "../libraries/LibPoolV1.sol";
import { LibPoolConfigV1 } from "../libraries/LibPoolConfigV1.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LinkedList } from "../../../libraries/LinkedList.sol";
import { PoolOracle } from "../../PoolOracle.sol";
import { LibReentrancyGuard } from "../libraries/LibReentrancyGuard.sol";

import { AdminFacetInterface } from "../interfaces/AdminFacetInterface.sol";

contract AdminFacet is AdminFacetInterface {
  using LinkedList for LinkedList.List;

  error AdminFacet_AllowTokensLengthMismatch();
  error AdminFacet_AllowTokensMismatch();
  error AdminFacet_BadFlashLoanFeeBps();
  error AdminFacet_BadNewFundingInterval();
  error AdminFacet_BadNewBorrowingRateFactor();
  error AdminFacet_BadNewFundingRateFactor();
  error AdminFacet_BadNewLiquidationFeeUsd();
  error AdminFacet_BadNewMaxLeverage();
  error AdminFacet_BadNewMintBurnFeeBps();
  error AdminFacet_BadNewPositionFeeBps();
  error AdminFacet_BadNewStableBorrowingRateFactor();
  error AdminFacet_BadNewStableTaxBps();
  error AdminFacet_BadNewStableSwapFeeBps();
  error AdminFacet_BadNewSwapFeeBps();
  error AdminFacet_BadNewTaxBps();
  error AdminFacet_ConfigContainsNotAcceptToken();
  error AdminFacet_Forbidden();
  error AdminFacet_TokenDecimalsMismatch();
  error AdminFacet_TokensConfigsLengthMisMatch();
  error AdminFacet_TokenWeightMismatch();
  error AdminFacet_TotalTokenWeightMismatch();

  // ---------
  // Constants
  // ---------
  uint256 internal constant MAX_FEE_BPS = 500;
  uint256 internal constant MIN_FUNDING_INTERVAL = 1 hours;
  // Max funding rate factor at 1% (10000 / 1000000 * 100 = 1%)
  uint256 internal constant MAX_FUNDING_RATE_FACTOR = 10000;
  uint256 internal constant MAX_BORROWING_RATE_FACTOR = 10000;
  uint256 internal constant MAX_LIQUIDATION_FEE_USD = 100 * 10**30;
  uint256 internal constant MIN_LEVERAGE = 10000;

  address internal constant LINKEDLIST_START = address(1);
  address internal constant LINKEDLIST_END = address(1);
  address internal constant LINKEDLIST_EMPTY = address(0);

  event DeleteTokenConfig(address token);
  event SetAllowLiquidator(address liquidator, bool allow);
  event SetFlashLoanFeeBps(
    uint256 prevFlashLoanFeeBps,
    uint256 flashLoanFeeBps
  );
  event SetIsAllowAllLiquidators(
    bool prevIsAllowAllLiquidators,
    bool isAllowAllLiquidators
  );
  event SetIsDynamicFeeEnable(
    bool prevIsDynamicFeeEnable,
    bool newIsDynamicFeeEnable
  );
  event SetIsLeverageEnable(
    bool prevIsLeverageEnable,
    bool newIsLeverageEnable
  );
  event SetPoolOracle(PoolOracle prevPoolOracle, PoolOracle newPoolOracle);
  event SetIsSwapEnable(bool prevIsSwapEnable, bool newIsSwapEnable);
  event SetMaxLeverage(uint256 prevMaxLeverage, uint256 newMaxLeverage);
  event SetMinProfitDuration(
    uint64 prevMinProfitDuration,
    uint64 newMinProfitDuration
  );
  event SetMintBurnFeeBps(uint256 prevFeeBps, uint256 newFeeBps);
  event SetFundingRate(
    uint64 prevFundingInterval,
    uint64 newFundingInterval,
    uint64 prevBorrowingRateFactor,
    uint64 newBorrowingRateFactor,
    uint64 prevStableBorrowingRateFactor,
    uint64 newStableBorrowingRateFactor,
    uint64 prevFundingRateFactor,
    uint64 newFundingRateFactor
  );
  event SetLiquidationFeeUsd(
    uint256 prevLiquidationFeeUsd,
    uint256 newLiquidationFeeUsd
  );
  event SetPositionFeeBps(
    uint256 prevPositionFeeBps,
    uint256 newPositionFeeBps
  );
  event SetRouter(address prevRouter, address newRouter);
  event SetStableSwapFeeBps(
    uint256 prevStableSwapFeeBps,
    uint256 newStableSwapFeeBps
  );
  event SetStableTaxBps(uint256 prevStableTaxBps, uint256 newStableTaxBps);
  event SetSwapFeeBps(uint256 prevSwapFeeBps, uint256 newSwapFeeBps);
  event SetTaxBps(uint256 prevTaxBps, uint256 newTaxBps);
  event SetTokenConfig(
    address token,
    LibPoolConfigV1.TokenConfig prevConfig,
    LibPoolConfigV1.TokenConfig newConfig
  );
  event SetTreasury(address prevTreasury, address newTreasury);
  event WithdrawFeeReserve(address token, address to, uint256 amount);
  event SetPlugin(address plugin, bool oldAllow, bool newAllow);

  modifier onlyOwner() {
    LibDiamond.enforceIsContractOwner();
    _;
  }

  modifier nonReentrant() {
    LibReentrancyGuard.lock();
    _;
    LibReentrancyGuard.unlock();
  }

  function setPoolOracle(PoolOracle newPoolOracle) external onlyOwner {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    // Sanity check
    newPoolOracle.roundDepth();

    emit SetPoolOracle(ds.oracle, newPoolOracle);
    ds.oracle = newPoolOracle;
  }

  function setAllowLiquidators(address[] calldata liquidators, bool allow)
    external
    onlyOwner
  {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    for (uint256 i = 0; i < liquidators.length; i++) {
      poolConfigDs.allowLiquidators[liquidators[i]] = allow;
      emit SetAllowLiquidator(liquidators[i], allow);
    }
  }

  function setFlashLoanFeeBps(uint64 newFlashLoanFeeBps) external onlyOwner {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    if (newFlashLoanFeeBps > MAX_FEE_BPS)
      revert AdminFacet_BadFlashLoanFeeBps();

    emit SetFlashLoanFeeBps(poolConfigDs.flashLoanFeeBps, newFlashLoanFeeBps);
    poolConfigDs.flashLoanFeeBps = newFlashLoanFeeBps;
  }

  function setFundingRate(
    uint64 newFundingInterval,
    uint64 newBorrowingRateFactor,
    uint64 newStableBorrowingRateFactor,
    uint64 newFundingRateFactor
  ) external onlyOwner {
    if (newFundingInterval < MIN_FUNDING_INTERVAL)
      revert AdminFacet_BadNewFundingInterval();
    if (newBorrowingRateFactor > MAX_BORROWING_RATE_FACTOR)
      revert AdminFacet_BadNewBorrowingRateFactor();
    if (newFundingRateFactor > MAX_FUNDING_RATE_FACTOR)
      revert AdminFacet_BadNewFundingRateFactor();
    if (newStableBorrowingRateFactor > MAX_FUNDING_RATE_FACTOR)
      revert AdminFacet_BadNewStableBorrowingRateFactor();

    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetFundingRate(
      poolConfigDs.fundingInterval,
      newFundingInterval,
      poolConfigDs.borrowingRateFactor,
      newBorrowingRateFactor,
      poolConfigDs.stableBorrowingRateFactor,
      newStableBorrowingRateFactor,
      poolConfigDs.fundingRateFactor,
      newFundingRateFactor
    );
    poolConfigDs.fundingInterval = newFundingInterval;
    poolConfigDs.borrowingRateFactor = newBorrowingRateFactor;
    poolConfigDs.stableBorrowingRateFactor = newStableBorrowingRateFactor;
    poolConfigDs.fundingRateFactor = newFundingRateFactor;
  }

  function setIsAllowAllLiquidators(bool _isAllowAllLiquidators)
    external
    onlyOwner
  {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetIsAllowAllLiquidators(
      poolConfigDs.isAllowAllLiquidators,
      _isAllowAllLiquidators
    );
    poolConfigDs.isAllowAllLiquidators = _isAllowAllLiquidators;
  }

  function setIsDynamicFeeEnable(bool newIsDynamicFeeEnable)
    external
    onlyOwner
  {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetIsDynamicFeeEnable(
      poolConfigDs.isDynamicFeeEnable,
      newIsDynamicFeeEnable
    );
    poolConfigDs.isDynamicFeeEnable = newIsDynamicFeeEnable;
  }

  function setIsLeverageEnable(bool newIsLeverageEnable) external onlyOwner {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetIsLeverageEnable(
      poolConfigDs.isLeverageEnable,
      newIsLeverageEnable
    );
    poolConfigDs.isLeverageEnable = newIsLeverageEnable;
  }

  function setIsSwapEnable(bool newIsSwapEnable) external onlyOwner {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetIsSwapEnable(poolConfigDs.isSwapEnable, newIsSwapEnable);
    poolConfigDs.isSwapEnable = newIsSwapEnable;
  }

  function setLiquidationFeeUsd(uint256 newLiquidationFeeUsd)
    external
    onlyOwner
  {
    if (newLiquidationFeeUsd > MAX_LIQUIDATION_FEE_USD)
      revert AdminFacet_BadNewLiquidationFeeUsd();

    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetLiquidationFeeUsd(
      poolConfigDs.liquidationFeeUsd,
      newLiquidationFeeUsd
    );
    poolConfigDs.liquidationFeeUsd = newLiquidationFeeUsd;
  }

  function setMaxLeverage(uint64 newMaxLeverage) external onlyOwner {
    if (newMaxLeverage <= MIN_LEVERAGE) revert AdminFacet_BadNewMaxLeverage();

    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetMaxLeverage(poolConfigDs.maxLeverage, newMaxLeverage);
    poolConfigDs.maxLeverage = newMaxLeverage;
  }

  function setMinProfitDuration(uint64 newMinProfitDuration)
    external
    onlyOwner
  {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetMinProfitDuration(
      poolConfigDs.minProfitDuration,
      newMinProfitDuration
    );
    poolConfigDs.minProfitDuration = newMinProfitDuration;
  }

  function setMintBurnFeeBps(uint64 newMintBurnFeeBps) external onlyOwner {
    if (newMintBurnFeeBps > MAX_FEE_BPS)
      revert AdminFacet_BadNewMintBurnFeeBps();

    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetMintBurnFeeBps(poolConfigDs.mintBurnFeeBps, newMintBurnFeeBps);
    poolConfigDs.mintBurnFeeBps = newMintBurnFeeBps;
  }

  function setPositionFeeBps(uint64 newPositionFeeBps) external onlyOwner {
    if (newPositionFeeBps > MAX_FEE_BPS)
      revert AdminFacet_BadNewPositionFeeBps();

    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetPositionFeeBps(poolConfigDs.positionFeeBps, newPositionFeeBps);
    poolConfigDs.positionFeeBps = newPositionFeeBps;
  }

  function setRouter(address newRouter) external onlyOwner {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetRouter(poolConfigDs.router, newRouter);
    poolConfigDs.router = newRouter;
  }

  function setSwapFeeBps(uint64 newSwapFeeBps, uint64 newStableSwapFeeBps)
    external
    onlyOwner
  {
    if (newSwapFeeBps > MAX_FEE_BPS) revert AdminFacet_BadNewSwapFeeBps();
    if (newStableSwapFeeBps > MAX_FEE_BPS)
      revert AdminFacet_BadNewStableSwapFeeBps();

    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetSwapFeeBps(poolConfigDs.swapFeeBps, newSwapFeeBps);
    emit SetStableSwapFeeBps(
      poolConfigDs.stableSwapFeeBps,
      newStableSwapFeeBps
    );

    poolConfigDs.swapFeeBps = newSwapFeeBps;
    poolConfigDs.stableSwapFeeBps = newStableSwapFeeBps;
  }

  function setTaxBps(uint64 newTaxBps, uint64 newStableTaxBps)
    external
    onlyOwner
  {
    if (newTaxBps > MAX_FEE_BPS) revert AdminFacet_BadNewTaxBps();
    if (newStableTaxBps > MAX_FEE_BPS) revert AdminFacet_BadNewStableTaxBps();

    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetTaxBps(poolConfigDs.taxBps, newTaxBps);
    emit SetStableTaxBps(poolConfigDs.stableTaxBps, newStableTaxBps);

    poolConfigDs.taxBps = newTaxBps;
    poolConfigDs.stableTaxBps = newStableTaxBps;
  }

  function setTokenConfigs(
    address[] calldata tokens,
    LibPoolConfigV1.TokenConfig[] calldata configs
  ) external onlyOwner {
    if (tokens.length != configs.length)
      revert AdminFacet_TokensConfigsLengthMisMatch();

    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    for (uint256 i = 0; i < tokens.length; ) {
      // Enforce that accept must be true
      if (!configs[i].accept) revert AdminFacet_ConfigContainsNotAcceptToken();

      // If tokenMetas.accept previously false, then it is a new token to be added.
      if (!poolConfigDs.tokenMetas[tokens[i]].accept)
        poolConfigDs.allowTokens.add(tokens[i]);

      emit SetTokenConfig(
        tokens[i],
        poolConfigDs.tokenMetas[tokens[i]],
        configs[i]
      );

      poolConfigDs.totalTokenWeight =
        (poolConfigDs.totalTokenWeight -
          poolConfigDs.tokenMetas[tokens[i]].weight) +
        configs[i].weight;
      poolConfigDs.tokenMetas[tokens[i]] = configs[i];

      unchecked {
        ++i;
      }
    }
  }

  function setTreasury(address newTreasury) external onlyOwner {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    emit SetTreasury(poolConfigDs.treasury, newTreasury);
    poolConfigDs.treasury = newTreasury;
  }

  function deleteTokenConfig(address token) external onlyOwner {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    // Update totalTokenWeight
    poolConfigDs.totalTokenWeight -= poolConfigDs.tokenMetas[token].weight;

    // Delete configs from storage
    poolConfigDs.allowTokens.remove(
      token,
      poolConfigDs.allowTokens.getPreviousOf(token)
    );
    delete poolConfigDs.tokenMetas[token];

    emit DeleteTokenConfig(token);
  }

  function withdrawFeeReserve(
    address token,
    address to,
    uint256 amount
  ) external nonReentrant {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    if (msg.sender != LibPoolConfigV1.treasury()) revert AdminFacet_Forbidden();

    ds.feeReserveOf[token] -= amount;
    LibPoolV1.pushTokens(token, to, amount);

    emit WithdrawFeeReserve(token, to, amount);
  }

  function setPlugin(address plugin, bool allow) external onlyOwner {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    emit SetPlugin(plugin, ds.plugins[plugin], allow);

    ds.plugins[plugin] = allow;
  }
}
