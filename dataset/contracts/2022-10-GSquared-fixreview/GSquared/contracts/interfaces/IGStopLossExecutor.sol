// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

interface IGStopLossExecutor {
    /// @notice returns true if keeper should call setStopLossPrimer for strategy
    function canUpdateStopLoss() external view returns (bool);

    /// @notice returns true if keeper should call stopStopLossPrimer for strategy
    function endStopLoss() external view returns (bool);

    /// @notice returns true if keeper should call executeStopLoss for strategy
    function canExecuteStopLossPrimer() external view returns (bool);

    /// @notice sets timer if update stop loss returns true
    function setStopLossPrimer() external;

    /// @notice resets timer if endStopLoss returns true
    function stopStopLossPrimer() external;

    /// @notice run stop loss function if canExecuteStopLossPrimer is true
    function executeStopLoss() external;

    /// @notice returns true if keeper can execute harvest
    function canHarvest() external view returns (bool);

    /// @notice run strategy harvest
    function harvest() external;
}
