// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title Uniquely identified seals management.
interface ISealsEvents {
    /// @notice Emitted when a seal is used.
    /// @param sealId the seal identifier.
    /// @param sealer the sealer address.
    event Sealed(uint256 sealId, address sealer);
}
