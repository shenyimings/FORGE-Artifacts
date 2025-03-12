// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./shared/MasterChefMainnetStrategy.sol";

contract MasterChefUsdcStrategy is MasterChefMainnetStrategy, USDC {
    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMasterChef _chef,
        IERC20 _rewardToken,
        uint256 _pid
    )
        MasterChefStrategyBase(_chef, _rewardToken, _pid, USDC_ADDRESS)
    {}
}
