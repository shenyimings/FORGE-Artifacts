// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./RewardStrategy.sol";
import "../shared/SwapHelperMainnet.sol";

abstract contract MultipleRewardStrategy is RewardStrategy, SwapHelperMainnet {
    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _claimRewards(SwapData[] calldata swapData) internal virtual override returns(Reward[] memory) {
        return _claimMultipleRewards(type(uint128).max, swapData);
    }

    function _claimFastWithdrawRewards(uint128 shares, SwapData[] calldata swapData) internal virtual override returns(Reward[] memory) {
        return _claimMultipleRewards(shares, swapData);
    }

    /* ========== VIRTUAL FUNCTIONS ========== */

    function _claimMultipleRewards(uint128 shares, SwapData[] calldata swapData) internal virtual returns(Reward[] memory rewards);
}
