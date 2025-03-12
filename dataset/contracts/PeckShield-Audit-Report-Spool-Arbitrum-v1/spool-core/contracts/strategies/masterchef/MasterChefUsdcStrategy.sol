// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./shared/MasterChefMainnetStrategy.sol";

/**
 * @notice MasterChef USDC Strategy implementation
 */
contract MasterChefUsdcStrategy is MasterChefMainnetStrategy, USDC {
    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _chef MasterChef contract
     * @param _rewardToken Reward token
     * @param _pid Pool ID
     */
    constructor(
        IMasterChef _chef,
        IERC20 _rewardToken,
        uint256 _pid
    )
        MasterChefStrategyBase(_chef, _rewardToken, _pid, USDC_ADDRESS)
    {}
}
