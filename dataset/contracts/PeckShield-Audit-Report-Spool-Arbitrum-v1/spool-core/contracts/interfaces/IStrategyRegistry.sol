// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

interface IStrategyRegistry {

    /* ========== FUNCTIONS ========== */

    function upgradeToAndCall(address strategy, bytes calldata data) external;
    function changeAdmin(address newAdmin) external;
    function addStrategy(address strategy) external;
    function getImplementation(address strategy) view external returns (address);

    /* ========== EVENTS ========== */

    /// @notice Emitted when the admin account has changed.
    event AdminChanged(address previousAdmin, address newAdmin);

    /// @notice Emitted when a strategy is upgraded
    event StrategyUpgraded(address strategy, address newImplementation);

    /// @notice Emitted when a new strategy is registered
    event StrategyRegistered(address strategy);
}
