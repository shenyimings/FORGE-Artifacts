// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ProcessStrategy.sol";
import "../shared/SwapHelper.sol";

struct Reward {
    uint256 amount;
    IERC20 token;
}

abstract contract RewardStrategy is ProcessStrategy, SwapHelper {

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _getStrategyUnderlyingWithRewards() internal view override virtual returns(uint128) {
        Strategy storage strategy = strategies[self];

        uint128 totalUnderlying = getStrategyBalance();
        totalUnderlying += strategy.pendingDepositReward;

        return totalUnderlying;
    }

    function _processFastWithdraw(uint128 shares, uint256[] memory slippages, SwapData[] calldata swapData) internal override virtual returns(uint128) {
        uint128 withdrawRewards = _processFastWithdrawalRewards(shares, swapData);

        uint128 withdrawRecieved = _withdraw(shares, slippages);

        return withdrawRecieved + withdrawRewards;
    }

    function _processRewards(SwapData[] calldata swapData) internal override virtual {
        Strategy storage strategy = strategies[self];

        Reward[] memory rewards = _claimRewards(swapData);

        uint128 collectedAmount = _sellRewards(rewards, swapData);

        if (collectedAmount > 0) {
            strategy.pendingDepositReward += collectedAmount;
        }
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _processFastWithdrawalRewards(uint128 shares, SwapData[] calldata swapData) internal virtual returns(uint128 withdrawalRewards) {
        Strategy storage strategy = strategies[self];

        Reward[] memory rewards = _claimFastWithdrawRewards(shares, swapData);
        
        withdrawalRewards += _sellRewards(rewards, swapData);
        
        if (strategy.pendingDepositReward > 0) {
            uint128 fastWithdrawCompound = (strategy.pendingDepositReward * shares) / strategy.totalShares;
            if (fastWithdrawCompound > 0) {
                strategy.pendingDepositReward -= fastWithdrawCompound;
                withdrawalRewards += fastWithdrawCompound;
            }
        }
    }

    function _sellRewards(Reward[] memory rewards, SwapData[] calldata swapData) internal virtual returns(uint128 collectedAmount) {
        for (uint256 i = 0; i < rewards.length; i++) {
            // add compound amount from current batch to the fast withdraw
            if (rewards[i].amount > 0) { 
                uint128 compoundAmount = SafeCast.toUint128(
                    _approveAndSwap(
                        rewards[i].token,
                        underlying,
                        rewards[i].amount,
                        swapData[i]
                    )
                );

                // add to pending reward
                collectedAmount += compoundAmount;
            }
        }
    }

    function _getRewardClaimAmount(uint128 shares, uint256 rewardAmount) internal virtual view returns(uint128) {
        // for do hard work claim everything
        if (shares == type(uint128).max) {
            return SafeCast.toUint128(rewardAmount);
        } else { // for fast withdrawal claim calculate user withdraw amount
            return SafeCast.toUint128((rewardAmount * shares) / strategies[self].totalShares);
        }
    }

    /* ========== VIRTUAL FUNCTIONS ========== */
    
    function _claimFastWithdrawRewards(uint128 shares, SwapData[] calldata swapData) internal virtual returns(Reward[] memory rewards);
    function _claimRewards(SwapData[] calldata swapData) internal virtual returns(Reward[] memory rewards);
}
