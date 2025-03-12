// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./RewardStrategy.sol";
import "../shared/SwapHelperMainnet.sol";

abstract contract ClaimFullSingleRewardStrategy is RewardStrategy, SwapHelperMainnet {
    /* ========== STATE VARIABLES ========== */

    IERC20 internal immutable rewardToken;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IERC20 _rewardToken
    ) {
        require(address(_rewardToken) != address(0), "ClaimFullSingleRewardStrategy::constructor: Token address cannot be 0");
        rewardToken = _rewardToken;
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _claimRewards(SwapData[] calldata swapData) internal override returns(Reward[] memory) {
        return _claimSingleRewards(type(uint128).max, swapData);
    }

    function _claimFastWithdrawRewards(uint128 shares, SwapData[] calldata swapData) internal override returns(Reward[] memory) {
        return _claimSingleRewards(shares, swapData);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _claimSingleRewards(uint128 shares, SwapData[] calldata swapData) private returns(Reward[] memory rewards) {
        if (swapData.length > 0 && swapData[0].slippage > 0) {
            uint128 rewardAmount = _claimStrategyReward();

            if (rewardAmount > 0) {
                Strategy storage strategy = strategies[self];

                uint128 claimedAmount = _getRewardClaimAmount(shares, rewardAmount);

                rewards = new Reward[](1);
                rewards[0] = Reward(claimedAmount, rewardToken);

                // if we don't claim all the rewards save the amount left, otherwise reset amount left to 0
                if (rewardAmount > claimedAmount) {
                    uint128 rewardAmountLeft = rewardAmount - claimedAmount;
                    strategy.pendingRewards[address(rewardToken)] = rewardAmountLeft;
                } else if (strategy.pendingRewards[address(rewardToken)] > 0) {
                    strategy.pendingRewards[address(rewardToken)] = 0;
                }
            }
        }
    }

    /* ========== VIRTUAL FUNCTIONS ========== */

    function _claimStrategyReward() internal virtual returns(uint128);
}