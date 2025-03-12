// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../../RewardStrategy.sol";
import "../../../external/interfaces/masterchef/IMasterChef.sol";

/**
 * @notice MasterChef strategy base logic
 */
abstract contract MasterChefStrategyBase is RewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice MasterChef contract
    IMasterChef public immutable chef;

    /// @notice Reward token contract
    IERC20 public immutable rewardToken;

    /// @notice Pool ID
    uint256 public immutable pid;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _chef MasterChef contract
     * @param _rewardToken Reward token
     * @param _pid Pool ID
     * @param _underlying Underlying asset
     */
    constructor(
        IMasterChef _chef,
        IERC20 _rewardToken,
        uint256 _pid,
        IERC20 _underlying
    )
        BaseStrategy(_underlying, 1, 0, 0, 0, true, false, address(0))
    {
        require(address(_chef) != address(0), "MasterChefStrategyBase::constructor: Masterchef address cannot be 0");
        require(address(_rewardToken) != address(0), "MasterChefStrategyBase::constructor: Token address cannot be 0");
        chef = _chef;
        rewardToken = _rewardToken;
        pid = _pid;
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Get strategy balance
     * @return Strategy balance
     */
    function getStrategyBalance() public view virtual override returns (uint128) {
        return SafeCast.toUint128(chef.userInfo(pid, address(this)).amount);
    }

    /**
     * @notice Validate rewards slippage
     * @dev Override reward slippage check as claim is forced and slippage can be empty array
     * @param swapData Slippage and path array
     */
    function _validateRewardsSlippage(SwapData[] calldata swapData) internal virtual view override {
        if (swapData.length > 0) {
            super._validateRewardsSlippage(swapData);
        }
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @notice Claim rewards
     * @param swapData Slippage and path array
     * @return rewards collected reward values
     */
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

    /**
     * @notice Claim and fast withdraw rewards
     * @param shares Shares to claim
     * @param swapData Slippage and path array
     * @return rewards collected reward values
     */
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

    /**
     * @notice Get reward
     * @return Reward amount
     */
    function _getReward() private returns(uint256) {
        Strategy storage strategy = strategies[self];

        uint256 rewardAmount = rewardToken.balanceOf(address(this));
        chef.withdraw(pid, 0);
        rewardAmount = rewardToken.balanceOf(address(this)) - rewardAmount;

        // add already claimed rewards (MasterChef automatically claims rewards on deposit/withdrawal)
        rewardAmount += strategy.pendingRewards[address(rewardToken)];

        return rewardAmount;
    }

    /**
     * @notice Deposit amount
     * @param amount Amount to deposit
     * @return amount Deposited amount
     */
    function _deposit(uint128 amount, uint256[] memory) internal virtual override returns(uint128) {
        underlying.safeApprove(address(chef), amount);
        chef.deposit(pid, amount);
        _resetAllowance(underlying, address(chef));
        return amount;
    }

    /**
     * @notice Withdraw shares
     * @param shares Shares to withdraw
     * @return Withdrawn shares
     */
    function _withdraw(uint128 shares, uint256[] memory) internal virtual override returns(uint128) {
        uint128 withdrawAmount = _getSharesToAmount(shares);
        chef.withdraw(pid, withdrawAmount);

        return withdrawAmount;
    }

    /**
     * @notice Withdraw in emergency
     */
    function _emergencyWithdraw(address, uint256[] calldata) internal virtual override {
        chef.emergencyWithdraw(pid);
    }
}