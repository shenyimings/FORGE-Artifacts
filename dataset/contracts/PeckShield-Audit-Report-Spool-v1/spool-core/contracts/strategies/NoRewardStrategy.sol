// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ProcessStrategy.sol";

abstract contract NoRewardStrategy is ProcessStrategy {
    /* ========== CONSTRUCTOR ========== */

    constructor(
        IERC20 _underlying,
        uint256 _processSlippageSlots,
        uint256 _reallocationSlippageSlots,
        uint256 _depositSlippageSlots
    )
        BaseStrategy(
            _underlying,
            0,
            _processSlippageSlots,
            _reallocationSlippageSlots,
            _depositSlippageSlots,
            false
        )
    {}

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _getStrategyUnderlyingWithRewards() internal view override virtual returns(uint128) {
        return getStrategyBalance();
    }

    function _processRewards(SwapData[] calldata) internal pure override {
        revert("NoRewardStrategy::_processRewards: Strategy does not have rewards");
    }

    function _processFastWithdraw(uint128 shares, uint256[] memory slippages, SwapData[] calldata) internal virtual override returns(uint128) {
        return _withdraw(shares, slippages);
    }

    function _validateRewardsSlippage(SwapData[] calldata) internal view override {}
}
