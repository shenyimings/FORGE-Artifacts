// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../MultipleRewardStrategy.sol";
import "../../external/interfaces/idle-finance/IIdleToken.sol";

contract IdleStrategy is MultipleRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IIdleToken public immutable idleToken;
    uint256 public immutable oneShare;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IIdleToken _idleToken,
        IERC20 _underlying
    )
        BaseStrategy(_underlying, 0, 1, 1, 1, true)
    {
        require(address(_idleToken) != address(0), "IdleStrategy::constructor: Token address cannot be 0");
        idleToken = _idleToken;
        oneShare = 10 ** uint256(_idleToken.decimals());
    }

    /* ========== VIEWS ========== */

    function getStrategyBalance() public view override returns(uint128) {
        uint256 idleTokenBalance = idleToken.balanceOf(address(this));
        return SafeCast.toUint128(_getIdleTokenValue(idleTokenBalance));
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @notice Dynamically return reward slippage length
     * @dev Reward slippage lenght corresponds with amount of reward tokens a strategy provides
     */
    function _getRewardSlippageSlots() internal view override returns(uint256) {
        return idleToken.getGovTokens().length;
    }

    function _deposit(uint128 amount, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(isDeposit, "IdleStrategy::_deposit: Withdraw slippage provided");

        // deposit underlying
        underlying.safeApprove(address(idleToken), amount);
        // NOTE: Middle Flag is unused so can be anything
        uint256 mintedIdleAmount = idleToken.mintIdleToken(
            amount,
            true,
            address(this)
        );

        require(
            mintedIdleAmount >= slippage,
            "IdleStrategy::_deposit: Insufficient Idle Amount Minted"
        );

        return SafeCast.toUint128(_getIdleTokenValue(mintedIdleAmount));
    }

    function _withdraw(uint128 shares, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(!isDeposit, "IdleStrategy::_withdraw: Deposit slippage provided");

        uint256 idleTokensTotal = idleToken.balanceOf(address(this));

        uint256 redeemIdleAmount = (idleTokensTotal * shares) / strategies[self].totalShares;

        // withdraw idle tokens from vault
        uint256 undelyingBefore = underlying.balanceOf(address(this));
        idleToken.redeemIdleToken(redeemIdleAmount);
        uint256 undelyingWithdrawn = underlying.balanceOf(address(this)) - undelyingBefore;

        require(
            undelyingWithdrawn >= slippage,
            "IdleStrategy::_withdraw: Insufficient withdrawn amount"
        );

        return SafeCast.toUint128(undelyingWithdrawn);
    }

    function _emergencyWithdraw(address, uint256[] calldata) internal override {
        idleToken.redeemIdleToken(idleToken.balanceOf(address(this)));
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _getIdleTokenValue(uint256 idleAmount) private view returns(uint256) {
        if (idleAmount == 0)
            return 0;
        
        return (idleAmount * idleToken.tokenPriceWithFee(address(this))) / oneShare;
    }

    /**
     * @dev Claim all idle governance reward tokens
     *  Force claiming tokens on every strategy interaction
     */
    function _claimMultipleRewards(uint128 shares, SwapData[] calldata _swapData) internal override returns(Reward[] memory rewards) {
        address[] memory rewardTokens = idleToken.getGovTokens();

        SwapData[] memory swapData = _swapData;
        if (swapData.length == 0) {
            // if no slippages provided we just loop over the rewards to save them
            swapData = new SwapData[](rewardTokens.length);
        } else {
            // init rewards array, to compound them
            rewards = new Reward[](rewardTokens.length);
        }

        uint256[] memory newRewardTokenAmounts = _claimStrategyRewards(rewardTokens);

        Strategy storage strategy = strategies[self];
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (swapData[i].slippage > 0) {
                uint256 rewardTokenAmount = newRewardTokenAmounts[i] + strategy.pendingRewards[rewardTokens[i]];
                if (rewardTokenAmount > 0) {
                    uint256 claimedAmount = _getRewardClaimAmount(shares, rewardTokenAmount);

                    if (rewardTokenAmount > claimedAmount) {
                        // if we don't swap all the tokens (fast withdraw), save the rest
                        uint256 rewardAmountLeft = rewardTokenAmount - claimedAmount;
                        strategy.pendingRewards[rewardTokens[i]] = rewardAmountLeft;
                    } else if (rewardTokenAmount > newRewardTokenAmounts[i]) {
                        // if reward amount is more than new rewards, we reset pendng to 0, otherwise it was 0 already
                        strategy.pendingRewards[rewardTokens[i]] = 0;
                    }

                    rewards[i] = Reward(claimedAmount, IERC20(rewardTokens[i]));
                }
            } else if (newRewardTokenAmounts[i] > 0) {
                strategy.pendingRewards[rewardTokens[i]] += newRewardTokenAmounts[i];
            }
        }
    }

    function _claimStrategyRewards(address[] memory rewardTokens) private returns(uint256[] memory) {
        uint256[] memory rewardTokenAmountsBefore = _getRewardTokenAmounts(rewardTokens);
        
        // claim
        idleToken.redeemIdleToken(0);

        uint256[] memory rewardTokenAmounts = new uint[](rewardTokens.length);

        // calculate reward token amounts
        for (uint256 i = 0; i < rewardTokenAmountsBefore.length; i++) {
            rewardTokenAmounts[i] = IERC20(rewardTokens[i]).balanceOf(address(this)) - rewardTokenAmountsBefore[i];
        }

        return rewardTokenAmounts;
    }

    function _getRewardTokenAmounts(address[] memory rewardTokens) private view returns(uint256[] memory) {
        uint256[] memory rewardTokenAmounts = new uint[](rewardTokens.length);

        for (uint256 i = 0; i < rewardTokenAmounts.length; i++) {
            rewardTokenAmounts[i] = IERC20(rewardTokens[i]).balanceOf(address(this));
        }

        return rewardTokenAmounts;
    }
}