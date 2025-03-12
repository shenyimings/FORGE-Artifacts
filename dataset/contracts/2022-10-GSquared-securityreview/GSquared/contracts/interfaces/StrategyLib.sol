// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

library strategyLib {
    struct StrategyParams {
        bool active;
        uint256 debtRatio;
        uint256 lastReport;
        uint256 totalDebt;
        uint256 totalGain;
        uint256 totalLoss;
    }
}
