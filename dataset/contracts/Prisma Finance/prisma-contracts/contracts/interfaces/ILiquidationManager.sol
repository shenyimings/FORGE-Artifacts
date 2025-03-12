// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Common interface for the Liquidation Manager.
interface ILiquidationManager {
    // --- Functions ---

    function enableCollateral(address _troveManager, address _collateral) external;

    function liquidate(address _borrower) external;

    function liquidateTroves(uint _n) external;

    function batchLiquidateTroves(address[] calldata _troveArray) external;
}
