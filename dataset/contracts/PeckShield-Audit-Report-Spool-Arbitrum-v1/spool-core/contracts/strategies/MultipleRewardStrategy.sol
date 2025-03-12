// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./RewardStrategy.sol";
import "../shared/SwapHelperMainnet.sol";

/**
 * @notice Multiple reward strategy logic
 */
abstract contract MultipleRewardStrategy is RewardStrategy, SwapHelperMainnet {
    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @notice Claim rewards
     * @param swapData Slippage and path array
     * @return Rewards
     */
    function _claimRewards(SwapData[] calldata swapData) internal virtual override returns(Reward[] memory) {
        return _claimMultipleRewards(type(uint128).max, swapData);
    }

    /**
     * @dev Claim fast withdraw rewards
     * @param shares Amount of shares
     * @param swapData Swap slippage and path
     * @return Rewards
     */
    function _claimFastWithdrawRewards(uint128 shares, SwapData[] calldata swapData) internal virtual override returns(Reward[] memory) {
        return _claimMultipleRewards(shares, swapData);
    }

    /* ========== VIRTUAL FUNCTIONS ========== */

    function _claimMultipleRewards(uint128 shares, SwapData[] calldata swapData) internal virtual returns(Reward[] memory rewards);
}
