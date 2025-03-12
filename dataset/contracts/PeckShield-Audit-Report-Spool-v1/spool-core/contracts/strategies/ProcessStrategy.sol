// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./BaseStrategy.sol";

import "../libraries/Max/128Bit.sol";
import "../libraries/Math.sol";

struct ProcessInfo {
    uint128 totalWithdrawRecieved;
    uint128 userDepositRecieved;
}

abstract contract ProcessStrategy is BaseStrategy {
    using Max128Bit for uint128;

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _process(uint256[] memory slippages, uint128 redistributeSharesToWithdraw) internal override virtual {
        // PREPARE
        Strategy storage strategy = strategies[self];
        uint24 processingIndex = _getProcessingIndex();
        Batch storage batch = strategy.batches[processingIndex];
        uint128 strategyTotalShares = strategy.totalShares;
        uint128 pendingSharesToWithdraw = strategy.pendingUser.sharesToWithdraw.get();
        uint128 userDeposit = strategy.pendingUser.deposit.get();

        // CALCULATE THE ACTION

        // if withdrawing for redistributing, add shares to total withdraw shares
        if (redistributeSharesToWithdraw > 0) {
            pendingSharesToWithdraw += redistributeSharesToWithdraw;
        }

        // total deposit recieved from users + compound reward (if there are any)
        uint128 totalPendingDeposit = userDeposit;
        
        // add compound reward (pendingDepositReward) to deposit
        uint128 withdrawalReward = 0;
        if (strategy.pendingDepositReward > 0) {
            uint128 pendingDepositReward = strategy.pendingDepositReward;

            totalPendingDeposit += pendingDepositReward;

            // calculate compound reward (withdrawalReward) for users withdrawing in this batch
            if (pendingSharesToWithdraw > 0 && strategyTotalShares > 0) {
                withdrawalReward = Math.getProportion128(pendingSharesToWithdraw, pendingDepositReward, strategyTotalShares);

                // substract withdrawal reward from total deposit
                totalPendingDeposit -= withdrawalReward;
            }

            // Reset pendingDepositReward
            strategy.pendingDepositReward = 0;
        }

        // if there is no pending deposit or withdrawals, return
        if (totalPendingDeposit == 0 && pendingSharesToWithdraw == 0) {
            return;
        }

        uint128 pendingWithdrawalAmount = 0;
        if (pendingSharesToWithdraw > 0) {
            pendingWithdrawalAmount = 
                Math.getProportion128(getStrategyBalance(), pendingSharesToWithdraw, strategyTotalShares);
        }

        // ACTION: DEPOSIT OR WITHDRAW
        ProcessInfo memory processInfo;
        if (totalPendingDeposit > pendingWithdrawalAmount) { // DEPOSIT
            // uint128 amount = totalPendingDeposit - pendingWithdrawalAmount;
            uint128 depositRecieved = _deposit(totalPendingDeposit - pendingWithdrawalAmount, slippages);

            processInfo.totalWithdrawRecieved = pendingWithdrawalAmount + withdrawalReward;

            // pendingWithdrawalAmount is optimized deposit: totalPendingDeposit - amount;
            uint128 totalDepositRecieved = depositRecieved + pendingWithdrawalAmount;
            
            // calculate user deposit recieved, excluding compound rewards
            processInfo.userDepositRecieved =  Math.getProportion128(totalDepositRecieved, userDeposit, totalPendingDeposit);
        } else if (totalPendingDeposit < pendingWithdrawalAmount) { // WITHDRAW
            // uint128 amount = pendingWithdrawalAmount - totalPendingDeposit;

            uint128 withdrawRecieved = _withdraw(
                // calculate back the shares from actual withdraw amount
                // NOTE: we can do unchecked calculation and casting as
                //       the multiplier is always smaller than the divisor
                Math.getProportion128Unchecked(
                    (pendingWithdrawalAmount - totalPendingDeposit),
                    pendingSharesToWithdraw,
                    pendingWithdrawalAmount
                ),
                slippages
            );

            // optimized withdraw is total pending deposit: pendingWithdrawalAmount - amount = totalPendingDeposit;
            processInfo.totalWithdrawRecieved = withdrawRecieved + totalPendingDeposit + withdrawalReward;
            processInfo.userDepositRecieved = userDeposit;
        } else {
            processInfo.totalWithdrawRecieved = pendingWithdrawalAmount + withdrawalReward;
            processInfo.userDepositRecieved = userDeposit;
        }
        
        // UPDATE STORAGE AFTER
        {
            uint128 stratTotalUnderlying = getStrategyBalance();

            // Update withdraw batch
            if (pendingSharesToWithdraw > 0) {
                batch.withdrawnRecieved = processInfo.totalWithdrawRecieved;
                batch.withdrawnShares = pendingSharesToWithdraw;
                
                strategyTotalShares -= pendingSharesToWithdraw;

                // update reallocation batch
                if (redistributeSharesToWithdraw > 0) {
                    BatchReallocation storage reallocationBatch = strategy.reallocationBatches[processingIndex];
                    reallocationBatch.withdrawnReallocationRecieved = Math.getProportion128(processInfo.totalWithdrawRecieved, redistributeSharesToWithdraw, pendingSharesToWithdraw);
                }
            }

            // Update deposit batch
            if (userDeposit > 0) {
                uint128 newShares = _getNewSharesAfterWithdraw(strategyTotalShares, stratTotalUnderlying, processInfo.userDepositRecieved);

                batch.deposited = userDeposit;
                batch.depositedRecieved = processInfo.userDepositRecieved;
                batch.depositedSharesRecieved = newShares;
                strategyTotalShares += newShares;
            }

            // Update shares
            if (strategyTotalShares != strategy.totalShares) {
                strategy.totalShares = strategyTotalShares;
            }

            // Set underlying at index
            strategy.totalUnderlying[processingIndex].amount = stratTotalUnderlying;
            strategy.totalUnderlying[processingIndex].totalShares = strategyTotalShares;
        }
    }

    function _processDeposit(uint256[] memory slippages) internal override virtual {
        Strategy storage strategy = strategies[self];
        
        uint128 depositOptimizedAmount = strategy.pendingRedistributeOptimizedDeposit;
        uint128 optimizedSharesWithdrawn = strategy.optimizedSharesWithdrawn;
        uint128 depositAmount = strategy.pendingRedistributeDeposit;

        // if a strategy is not part of reallocation return
        if (
            depositOptimizedAmount == 0 &&
            optimizedSharesWithdrawn == 0 &&
            depositAmount == 0
        ) {
            return;
        }

        uint24 processingIndex = _getProcessingIndex();
        BatchReallocation storage reallocationBatch = strategy.reallocationBatches[processingIndex];
        
        uint128 strategyTotalShares = strategy.totalShares;
        
        // get shares from optimized deposit
        if (depositOptimizedAmount > 0) {
            uint128 stratTotalUnderlying = getStrategyBalance();
            uint128 newShares = _getNewShares(strategyTotalShares, stratTotalUnderlying, depositOptimizedAmount);

            // add new shares
            strategyTotalShares += newShares;

            // update reallocation batch
            reallocationBatch.depositedReallocation = depositOptimizedAmount;
            reallocationBatch.depositedReallocationSharesRecieved = newShares;

            strategy.totalUnderlying[processingIndex].amount = stratTotalUnderlying;

            // reset
            strategy.pendingRedistributeOptimizedDeposit = 0;
        }

        // remove optimized withdraw shares
        if (optimizedSharesWithdrawn > 0) {
            strategyTotalShares -= optimizedSharesWithdrawn;

            // reset
            strategy.optimizedSharesWithdrawn = 0;
        }

        // get shares from actual deposit
        if (depositAmount > 0) {
            // deposit
            uint128 depositRecieved = _deposit(depositAmount, slippages);

            // NOTE: might return it from _deposit (only certain strategies need it)
            uint128 stratTotalUnderlying = getStrategyBalance();

            uint128 newShares = _getNewSharesAfterWithdraw(strategyTotalShares, stratTotalUnderlying, depositRecieved);

            // add new shares
            strategyTotalShares += newShares;

            // update reallocation batch
            reallocationBatch.depositedReallocation += depositRecieved;
            reallocationBatch.depositedReallocationSharesRecieved += newShares;

            strategy.totalUnderlying[processingIndex].amount = stratTotalUnderlying;

            // reset
            strategy.pendingRedistributeDeposit = 0;
        }

        // update share storage
        strategy.totalUnderlying[processingIndex].totalShares = strategyTotalShares;
        strategy.totalShares = strategyTotalShares;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _getSharesToAmount(uint256 shares) internal virtual returns(uint128 amount) {
        amount = Math.getProportion128( getStrategyBalance(), shares, strategies[self].totalShares );
    }

    /**
     * @dev get slippage, and action type (withdraw/deposit).
     * Most significant bit represents an action, 0 for withdrawal and 1 for deposit.
     */
    function _getSlippageAction(uint256 slippageAction) internal pure returns (bool isDeposit, uint256 slippage) {
        // remove most significant bit
        slippage = (slippageAction << 1) >> 1;

        // if numbers are not the same set action to deposit
        if (slippageAction != slippage) {
            isDeposit = true;
        }
    }

    /* ========== VIRTUAL FUNCTIONS ========== */

    function _deposit(uint128 amount, uint256[] memory slippages) internal virtual returns(uint128 depositRecieved);
    function _withdraw(uint128 shares, uint256[] memory slippages) internal virtual returns(uint128 withdrawRecieved);
}
