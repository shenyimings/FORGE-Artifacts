// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./shared/MasterChefMainnetStrategy.sol";

/**
 * @notice MasterChef strategy implementation
 */
contract MasterChefStrategy is MasterChefMainnetStrategy {
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
        MasterChefStrategyBase(_chef, _rewardToken, _pid, _underlying)
    {}
}
