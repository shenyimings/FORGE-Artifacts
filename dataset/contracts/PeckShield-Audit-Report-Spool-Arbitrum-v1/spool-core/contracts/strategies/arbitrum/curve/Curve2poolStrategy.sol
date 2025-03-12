// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../ClaimFullSingleRewardStrategy.sol";
import "./base/CurveStrategy2CoinsBase.sol";

import "../../../external/interfaces/curve/ILiquidityGauge.sol";
import "../../../external/interfaces/curve/IMinter.sol";
import "../../../interfaces/ISingleRewardStrategyContractHelper.sol";

/**
 * @notice Curve 2 pool strategy implementation
 */
contract Curve2poolStrategy is ClaimFullSingleRewardStrategy, CurveStrategy2CoinsBase {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice curve LP helper
    ISingleRewardStrategyContractHelper public immutable gaugeHelper;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _pool Stable swap pool contract
     * @param _lpToken LP token contract
     * @param _rewardToken Reward token
     * @param _underlying Underlying asset contract
     * @param _gaugeHelper Strategy contract helper
     */
    constructor(
        IStableSwap2Pool _pool,
        IERC20 _lpToken,
        IERC20 _rewardToken,
        IERC20 _underlying,
        ISingleRewardStrategyContractHelper _gaugeHelper,
        address _self
    )
        BaseStrategy(_underlying, 1, 1, 1, 1, false, true, _self)
        CurveStrategyBaseV3(address(_pool), _lpToken)
        ClaimFullSingleRewardStrategy(_rewardToken)
        SwapHelper(Protocol.UNISWAP)
    {
        gaugeHelper = _gaugeHelper;
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @dev Transfers lp tokens to helper contract, to deposit them into curve
     * @param lp deposit lp token amount
     */
    function _handleDeposit(uint256 lp, uint256) internal override returns(uint) {
        lpToken.safeTransfer(address(gaugeHelper), lp);

        gaugeHelper.deposit(lp);

        return lp;
    }

    /**
     * @dev Withdraw lp tokens from helper contract
     * @param lp withdraw lp token amount
     */
    function _handleWithdrawal(uint256 lp, uint256) internal override returns(uint) {

        gaugeHelper.withdraw(lp);

        return lp;
    }

    /**
     * @dev Handle emergency withdrawal
     * @param data Values to perform emergency withdraw
     */
    function _handleEmergencyWithdrawal(address, uint256[] calldata data) internal override {
        // NOTE: withdrawAll removes all lp tokens from the liquidity gauge,
        //       including the tokens from the other strategies in the same pool
        uint256 value = data.length > 0 ? data[0] : 0;

        if (value == 0) {
            gaugeHelper.withdraw(_lpBalance());
            strategies[self].lpTokens = 0;
        } else {
            (bool withdrawAll, uint256 lpTokens) = _getSlippageAction(value);

            if (withdrawAll) {
                gaugeHelper.withdrawAll();
                strategies[self].lpTokens = 0;
            } else {
                gaugeHelper.withdraw(lpTokens);

                if (lpTokens >= strategies[self].lpTokens) {
                    strategies[self].lpTokens = 0;
                } else {
                    strategies[self].lpTokens -= lpTokens;
                }
            }
        }
    }

    /**
     * @dev Claim strategy reward
     * @return Claimed rewards
     */
    function _claimStrategyReward() internal override returns(uint128) {
        (
            uint256 rewardTokenAmount,
            bool didClaimNewRewards
        ) = gaugeHelper.claimReward(true);
        

        if (didClaimNewRewards) {
            Strategy storage strategy = strategies[self];
            if (rewardTokenAmount > 0) {
                strategy.pendingRewards[address(rewardToken)] += rewardTokenAmount;
            }
        }

        return SafeCast.toUint128(strategies[self].pendingRewards[address(rewardToken)]);
    }

    /* ========== PRIVATE FUNCTIONS ========== */
}
