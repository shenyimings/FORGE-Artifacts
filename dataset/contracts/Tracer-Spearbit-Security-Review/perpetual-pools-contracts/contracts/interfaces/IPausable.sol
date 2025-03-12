//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

/// @title The pausable contract
interface IPausable {
    /**
     * @notice Pauses the pool
     * @dev Prevents all state updates until unpaused
     */
    function pause() external;

    /**
     * @notice Unpauses the pool
     * @dev Prevents all state updates until unpaused
     */
    function unpause() external;

    /**
     * @return true if paused
     */
    function paused() external returns (bool);

    event Paused();
    event Unpaused();
}
