// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../../RewardStrategy.sol";
import "../../../external/interfaces/masterchef/IMasterChef.sol";

abstract contract MasterChefStrategyBase is RewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */
    
    IMasterChef public immutable chef;
    IERC20 public immutable rewardToken;
    uint256 public immutable pid;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMasterChef _chef,
        IERC20 _rewardToken,
        uint256 _pid,
        IERC20 _underlying
    )
        BaseStrategy(_underlying, 1, 0, 0, 0, true)
    {
        require(address(_chef) != address(0), "MasterChefStrategyBase::constructor: Masterchef address cannot be 0");
        require(address(_rewardToken) != address(0), "MasterChefStrategyBase::constructor: Token address cannot be 0");
        chef = _chef;
        rewardToken = _rewardToken;
        pid = _pid;
    }

    /* ========== VIEWS ========== */

    function getStrategyBalance() public view virtual override returns (uint128) {
        return SafeCast.toUint128(chef.userInfo(pid, address(this)).amount);
    }

    // override reward slippage check as claim is forced and slippage can be empty array
    function _validateRewardsSlippage(SwapData[] calldata swapData) internal virtual view override {
        if (swapData.length > 0) {
            super._validateRewardsSlippage(swapData);
        }
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _claimRewards(SwapData[] calldata swapData) internal virtual override returns(Reward[] memory rewards) {
        Strategy storage strategy = strategies[self];
        uint256 rewardAmount = _getReward();
        
        if (rewardAmount > 0) {
            if (swapData.length > 0 && swapData[0].slippage > 0) {
                rewards = new Reward[](1);
                rewards[0] = Reward(rewardAmount, rewardToken);

                if (strategy.pendingRewards[address(rewardToken)] > 0) {
                    strategy.pendingRewards[address(rewardToken)] = 0;
                }
            } else {
                strategy.pendingRewards[address(rewardToken)] = rewardAmount;
            }
        }
    }

    function _claimFastWithdrawRewards(uint128 shares, SwapData[] calldata swapData) internal virtual override returns(Reward[] memory rewards) {
        Strategy storage strategy = strategies[self];
        uint256 rewardAmount = _getReward();

        if (rewardAmount > 0) {
            if (swapData.length > 0 && swapData[0].slippage > 0) {
                // calculate user share of reward
                uint256 userPendingReward = (rewardAmount * shares) / strategy.totalShares;

                if (userPendingReward > 0) {
                    rewards = new Reward[](1);
                    rewards[0] = Reward(userPendingReward, rewardToken);

                    rewardAmount -= userPendingReward;
                }
            }
            
            // store amount of pending reward tokens
            strategy.pendingRewards[address(rewardToken)] = rewardAmount;
        }
    }

    function _getReward() private returns(uint256) {
        Strategy storage strategy = strategies[self];

        uint256 rewardAmount = rewardToken.balanceOf(address(this));
        chef.withdraw(pid, 0);
        rewardAmount = rewardToken.balanceOf(address(this)) - rewardAmount;

        // add already claimed rewards (MasterChef automatically claims rewards on deposit/withdrawal)
        rewardAmount += strategy.pendingRewards[address(rewardToken)];

        return rewardAmount;
    }

    function _deposit(uint128 amount, uint256[] memory) internal virtual override returns(uint128) {
        underlying.safeApprove(address(chef), amount);
        chef.deposit(pid, amount);

        return amount;
    }

    function _withdraw(uint128 shares, uint256[] memory) internal virtual override returns(uint128) {
        chef.withdraw(pid, _getSharesToAmount(shares));

        return SafeCast.toUint128(shares);
    }

    function _emergencyWithdraw(address, uint256[] calldata) internal virtual override {
        chef.emergencyWithdraw(pid);
    }
}