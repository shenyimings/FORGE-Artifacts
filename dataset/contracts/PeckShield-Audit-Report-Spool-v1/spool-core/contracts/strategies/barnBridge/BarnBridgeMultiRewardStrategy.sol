// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../MultipleRewardStrategy.sol";

import "../../external/interfaces/barnbridge/ISmartYield.sol";
import "../../external/interfaces/barnbridge/IPoolMulti.sol";

contract BarnBridgeMultiRewardStrategy is MultipleRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    ISmartYield public immutable yield;
    IPoolMulti public immutable rewardPool;
    address public immutable provider;
    uint256 public immutable EXP_SCALE;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        ISmartYield _yield,
        IPoolMulti _rewardPool,
        IERC20 _underlying
    )
        BaseStrategy(_underlying, 0, 1, 1, 1, false)
    {
        require(
            _yield != ISmartYield(address(0)),
            "BarnBridgeMultiRewardStrategy::constructor: ISmartYield address cannot be 0"
        );
        require(
            _rewardPool != IPoolMulti(address(0)),
            "BarnBridgeMultiRewardStrategy::constructor: IPoolMulti address cannot be 0"
        );

        yield = _yield;
        rewardPool = _rewardPool;
        provider = _yield.pool();
        EXP_SCALE = _yield.EXP_SCALE();
    }

    /* ========== VIEWS ========== */

    function getStrategyBalance() public view override returns(uint128) {
        uint256 bbAmount = rewardPool.balances(address(this));
        return _getStrategyBalance(bbAmount);
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @dev Dynamically return reward slippage length
     */
    function _getRewardSlippageSlots() internal view override returns(uint256) {
        return rewardPool.numRewardTokens();
    }

    function _claimMultipleRewards(uint128 shares, SwapData[] calldata swapData) internal override returns(Reward[] memory rewards) {
        if (swapData.length > 0) {

            uint256 rewardTokensCount = rewardPool.numRewardTokens();
            rewards = new Reward[](rewardTokensCount);

            Strategy storage strategy = strategies[self];
            for (uint256 i = 0; i < rewardTokensCount; i++) {
                if (swapData[i].slippage > 0) {
                    address rewardToken = rewardPool.rewardTokens(i);
                    uint256 newRewardTokenAmount = _claimStrategyReward(rewardToken);

                    uint256 rewardTokenAmount = newRewardTokenAmount + strategy.pendingRewards[rewardToken];

                    if (rewardTokenAmount > 0) {
                        uint256 claimedAmount = _getRewardClaimAmount(shares, rewardTokenAmount);

                        if (rewardTokenAmount > claimedAmount) {
                            // if we don't swap all the tokens (fast withdraw), save the rest
                            uint256 rewardAmountLeft = rewardTokenAmount - claimedAmount;
                            strategy.pendingRewards[rewardToken] = rewardAmountLeft;
                        } else if (rewardTokenAmount > newRewardTokenAmount) {
                            // if reward amount is more than new rewards, we reset pendng to 0, otherwise it was 0 already
                            strategy.pendingRewards[rewardToken] = 0;
                        }

                        rewards[i] = Reward(claimedAmount, IERC20(rewardToken));
                    }
                }
            }
        }
    }

    function _deposit(uint128 amount, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(isDeposit, "BarnBridgeMultiRewardStrategy::_deposit: Withdraw slippage provided");

        underlying.safeApprove(provider, amount);
        yield.buyTokens(amount, slippage, block.timestamp);

        uint256 bbAmount = yield.balanceOf(address(this));
        
        // deposit junior tokens to reward pool
        yield.approve(address(rewardPool), bbAmount);
        rewardPool.deposit(bbAmount);

        uint128 underlyingDeposited = _getStrategyBalance(bbAmount);

        return underlyingDeposited;
    }

    function _withdraw(uint128 shares, uint256[] memory slippages) internal override returns(uint128) {
        // uint256 shares = amount.mul(EXP_SCALE).div(yield.price());
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(!isDeposit, "BarnBridgeMultiRewardStrategy::_withdraw: Deposit slippage provided");

        uint256 bbAmount = rewardPool.balances(address(this));

        // // withdraw from reward pool
        uint256 poolShares = (shares * bbAmount) / strategies[self].totalShares;
        rewardPool.withdraw(poolShares);

        // sell tokens
        uint256 underlyingBefore = underlying.balanceOf(address(this));
        yield.sellTokens(poolShares, slippage, block.timestamp);
        uint256 underlyingWithdrawn = underlying.balanceOf(address(this)) - underlyingBefore;

        return SafeCast.toUint128(underlyingWithdrawn);
    }

    function _emergencyWithdraw(address, uint256[] calldata data) internal override {
        uint256 bbAmount = rewardPool.balances(address(this));
        rewardPool.withdraw(bbAmount);

        uint256 slippage = data.length > 0 ? data[0] : 0;

        yield.sellTokens(bbAmount, slippage, block.timestamp);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _getStrategyBalance(uint256 bbAmount) private view returns(uint128) {
        if (bbAmount == 0)
            return 0;

        uint256 forfeits = (((bbAmount * EXP_SCALE) / yield.totalSupply()) * (yield.abondDebt())) / EXP_SCALE;

        uint256 result = ((bbAmount * yield.price()) / EXP_SCALE) - forfeits;
        return SafeCast.toUint128(result);
    }

    function _claimStrategyReward(address rewardToken) private returns(uint256) {
        uint256 claimedRewards = rewardPool.claim(rewardToken);

        return claimedRewards;
    }
}