// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./shared/MasterChefMainnetStrategy.sol";

contract MasterChefStrategy is MasterChefMainnetStrategy {
    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMasterChef _chef,
        IERC20 _rewardToken,
        uint256 _pid,
        IERC20 _underlying
    )
        MasterChefStrategyBase(_chef, _rewardToken, _pid, _underlying)
    {}
}
