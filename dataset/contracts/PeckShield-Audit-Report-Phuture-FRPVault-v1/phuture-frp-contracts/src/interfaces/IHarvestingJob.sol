// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.13;

import "../interfaces/IFRPHarvester.sol";

/// @title Harvester interface
/// @notice Contains harvesting and pausing logic
interface IHarvestingJob {
    /// @notice Pause harvesting job
    function pause() external;

    /// @notice Unpause harvesting job
    function unpause() external;

    /// @notice Harvests from vault
    /// @param _maxDepositedAmount Max amount of asset to deposit to Notional
    /// @param _vault Address of the FRPVault
    function harvest(uint _maxDepositedAmount, IFRPHarvester _vault) external;
}
