// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../ClaimFullSingleRewardStrategy.sol";
import "../../../external/interfaces/abracadabra/ISorbettiere.sol";
import "../../../interfaces/ISingleRewardStrategyContractHelper.sol";
import "../curve/base/CurveStrategyMetapoolV2Base.sol";
import "../MultipleRewardStrategy.sol";

/**
 * @notice abracadabra.money metapool strategy implementation
 */
contract AbracadabraMetapoolStrategy is ClaimFullSingleRewardStrategy, CurveStrategyMetapoolV2Base {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice Abracadabra.money farm where we get SPELL tokens
    ISorbettiere public immutable farm;
    /// @notice Farm helper contract
    ISingleRewardStrategyContractHelper public immutable farmHelper;

    /* ========== CONSTRUCTOR ========== */


    /**
     * @notice Set initial values
     * @param _farm Farm contract
     * @param _basePool Address of the base Curve pool
     * @param _depositZap Deposit Zap contract
     * @param _lpToken LP token contract (factoryPool)
     * @param _underlying Underlying asset
     * @param _farmHelper Strategy contract helper
     */
    constructor(
        ISorbettiere _farm,
        ICurvePool _basePool,
        address _depositZap,
        IERC20 _lpToken,
        IERC20 _underlying,
        ISingleRewardStrategyContractHelper _farmHelper,
        address _self
    )
        BaseStrategy(_underlying, 1, 1, 1, 1, false, true, _self)
        CurveStrategyBaseV3(_depositZap, _lpToken)
        CurveStrategyMetapoolV2Base(_basePool)
        ClaimFullSingleRewardStrategy(IERC20(_farm.ice()))
        SwapHelper(Protocol.SUSHISWAP)
    {
        require(address(_farm) != address(0), "AbracadabraMetapoolStrategy::constructor: Farm address cannot be 0");
        farm = _farm;

        (address stakingToken,,,,) = _farm.poolInfo(0);

        require(stakingToken == address(_lpToken), "AbracadabraMetapoolStrategy::constructor: Farm and curve lp tokens not the same");
        
        farmHelper = _farmHelper;
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @dev Transfers lp tokens to helper contract, to deposit them into farm
     */
    function _handleDeposit(uint256 lp, uint256) internal override returns(uint) {
        lpToken.safeTransfer(address(farmHelper), lp);

        farmHelper.deposit(lp);

        return lp;
    }

    /**
     * @dev Withdraw lp tokens from helper contract
     */
    function _handleWithdrawal(uint256 lp, uint256) internal override returns(uint) {

        farmHelper.withdraw(lp);

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
            farmHelper.withdraw(_lpBalance());
            strategies[self].lpTokens = 0;
        } else {
            (bool withdrawAll, uint256 lpTokens) = _getSlippageAction(value);
            
            if (withdrawAll) {
                farmHelper.withdrawAll();
                strategies[self].lpTokens = 0;
            } else {
                farmHelper.withdraw(lpTokens);

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
        ) = farmHelper.claimReward(true);
        

        if (didClaimNewRewards) {
            Strategy storage strategy = strategies[self];
            if (rewardTokenAmount > 0) {
                strategy.pendingRewards[address(rewardToken)] += rewardTokenAmount;
            }
        }

        return SafeCast.toUint128(strategies[self].pendingRewards[address(rewardToken)]);
    }
}
