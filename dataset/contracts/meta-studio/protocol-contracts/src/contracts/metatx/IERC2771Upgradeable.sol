// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

/// @title IERC2771Upgradeable
/// @dev Definition of IERC2771Upgradeable Interface
interface IERC2771Upgradeable {
    /// @notice Checks if an address is a `trusted forwarder`
    /// @param addr address to check
    /// @return true if the address is the trusted forwarder otherwise false
    function isTrustedForwarder(address addr) external view returns (bool);
}
