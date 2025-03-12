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

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibPoolV1 } from "../libraries/LibPoolV1.sol";
import { LibPoolConfigV1 } from "../libraries/LibPoolConfigV1.sol";
import { LibAccessControl } from "../libraries/LibAccessControl.sol";
import { LibReentrancyGuard } from "../libraries/LibReentrancyGuard.sol";
import { AccessControlFacetInterface } from "../interfaces/AccessControlFacetInterface.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FarmFacetInterface } from "../interfaces/FarmFacetInterface.sol";
import { StrategyInterface } from "../../../interfaces/StrategyInterface.sol";

contract FarmFacet is FarmFacetInterface {
  using SafeERC20 for ERC20;
  using SafeCast for uint256;

  error FarmFacet_BadTargetBps();
  error FarmFacet_InvalidRealizedProfits();
  error FarmFacet_InvalidWithdrawal();
  error FarmFacet_TooEarlyToCommitStrategy();
  error FarmFacet_InvalidFarmCaller();

  uint256 internal constant STRATEGY_DELAY = 1 weeks;
  uint256 internal constant MAX_TARGET_BPS = 9500; // 95%

  event SetStrategy(address token, StrategyInterface strategy);
  event SetPendingStrategy(address token, StrategyInterface strategy);
  event SetStrategyTargetBps(address token, uint256 targetBps);
  event StrategyDivest(address token, uint256 amount);
  event StrategyInvest(address token, uint256 amount);
  event StrategyRealizedProfit(address token, uint256 amount);
  event StrategyRealizedLoss(address token, uint256 amount);

  modifier onlyOwner() {
    LibDiamond.enforceIsContractOwner();
    _;
  }

  modifier nonReentrant() {
    LibReentrancyGuard.lock();
    _;
    LibReentrancyGuard.unlock();
  }

  modifier onlyPoolDiamondOrFarmKeeper() {
    if (
      msg.sender != address(this) &&
      !AccessControlFacetInterface(address(this)).hasRole(
        LibAccessControl.FARM_KEEPER,
        msg.sender
      )
    ) {
      revert FarmFacet_InvalidFarmCaller();
    }
    _;
  }

  function setStrategyOf(address token, StrategyInterface newStrategy)
    external
    onlyOwner
    nonReentrant
  {
    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    LibPoolConfigV1.StrategyData memory strategyData = poolConfigDs
      .strategyDataOf[token];
    StrategyInterface pendingStrategy = poolConfigDs.pendingStrategyOf[token];
    if (strategyData.startTimestamp == 0 || pendingStrategy != newStrategy) {
      // When adding new strategy or changing strategy
      poolConfigDs.pendingStrategyOf[token] = newStrategy;
      emit SetPendingStrategy(token, newStrategy);
      strategyData.startTimestamp = uint64(block.timestamp + STRATEGY_DELAY);
    } else {
      // When committing a new strategy
      if (
        strategyData.startTimestamp == 0 ||
        block.timestamp < strategyData.startTimestamp
      ) revert FarmFacet_TooEarlyToCommitStrategy();
      if (address(poolConfigDs.strategyOf[token]) != address(0)) {
        // If there is previous strategy, we need to withdraw all funds from it
        int256 balanceChange = poolConfigDs.strategyOf[token].exit(
          strategyData.principle
        );
        // Update totalOf[token] to sync physical balance with pool state
        LibPoolV1.updateTotalOf(token);
        // Realized profits/losses
        if (balanceChange > 0) {
          uint256 profit = uint256(balanceChange);
          LibPoolV1.increasePoolLiquidity(token, profit);

          emit StrategyRealizedProfit(token, profit);
        } else if (balanceChange < 0) {
          uint256 loss = uint256(-balanceChange);
          LibPoolV1.decreasePoolLiquidity(token, loss);

          emit StrategyRealizedLoss(token, loss);
        }

        emit StrategyDivest(token, strategyData.principle);
      }
      // Commit new strategy
      poolConfigDs.strategyOf[token] = newStrategy;
      strategyData.startTimestamp = 0;
      strategyData.principle = 0;
      poolConfigDs.pendingStrategyOf[token] = StrategyInterface(address(0));

      emit SetStrategy(token, newStrategy);
    }
    poolConfigDs.strategyDataOf[token] = strategyData;
  }

  function setStrategyTargetBps(address token, uint64 targetBps)
    external
    onlyOwner
  {
    if (targetBps > MAX_TARGET_BPS) revert FarmFacet_BadTargetBps();

    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();
    poolConfigDs.strategyDataOf[token].targetBps = targetBps;

    emit SetStrategyTargetBps(token, targetBps);
  }

  function farm(address token, bool isRebalanceNeeded)
    external
    onlyPoolDiamondOrFarmKeeper
  {
    // Load PoolV1 diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    // Load PoolConfig Diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    // Load relevant variables
    LibPoolConfigV1.StrategyData memory strategyData = poolConfigDs
      .strategyDataOf[token];
    StrategyInterface strategy = poolConfigDs.strategyOf[token];

    // Realized profits or losses from strategy
    int256 balanceChange = strategy.realized(strategyData.principle);
    // If there is no change in balance, and does not need to rebalance, then stop it here.
    if (balanceChange == 0 && !isRebalanceNeeded) return;

    if (balanceChange > 0) {
      // If there is a profit, then increase pool liquidity
      uint256 profits = uint256(balanceChange);
      LibPoolV1.increasePoolLiquidity(token, profits);

      LibPoolV1.updateTotalOf(token);

      emit StrategyRealizedProfit(token, profits);
    } else if (balanceChange < 0) {
      // If there is a loss, then decrease pool liquidity
      uint256 losses = uint256(-balanceChange);
      LibPoolV1.decreasePoolLiquidity(token, losses);
      strategyData.principle -= losses.toUint128();

      emit StrategyRealizedLoss(token, losses);
    }

    // If rebalance to make sure the strategy has the right amount of funds to deploy, then do it.
    if (isRebalanceNeeded) {
      // Calculate the target amount of funds to be deployed
      uint256 targetDeployedFunds = ((poolV1ds.liquidityOf[token] -
        poolV1ds.reservedOf[token]) * strategyData.targetBps) / 10000;

      if (strategyData.principle < targetDeployedFunds) {
        // If strategy short of funds, then deposit more funds
        // Find out how much more funds to deposit
        uint256 amountOut = targetDeployedFunds - strategyData.principle;

        // Transfer funds from pool to strategy and run it
        LibPoolV1.pushTokens(token, address(strategy), amountOut);
        strategy.run(amountOut);

        // Update how much pool put in the strategy
        strategyData.principle += amountOut.toUint128();

        emit StrategyInvest(token, amountOut);
      } else if (strategyData.principle > targetDeployedFunds) {
        // If strategy has more funds than it should be, then withdraw some funds
        // Find out how much funds to withdraw
        uint256 amountIn = strategyData.principle - targetDeployedFunds;

        // Withdraw funds from strategy and transfer it back to pool
        uint256 actualAmountIn = strategy.withdraw(amountIn);

        // Update how much pool put in the strategy
        strategyData.principle -= actualAmountIn.toUint128();

        LibPoolV1.updateTotalOf(token);

        emit StrategyDivest(token, actualAmountIn);
      }
    }

    poolConfigDs.strategyDataOf[token] = strategyData;
  }
}
