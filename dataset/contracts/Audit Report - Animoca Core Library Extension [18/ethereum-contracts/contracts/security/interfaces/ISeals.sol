// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ISealsEvents} from "../events/ISealsEvents.sol";

/// @title Uniquely identified seals management.
interface ISeals is ISealsEvents {
    /// @notice Retrieves whether a seal has been used already.
    /// @param sealId the seal identifier.
    /// @return wasSealed Whether a seal has been used already.
    function isSealed(uint256 sealId) external view returns (bool wasSealed);
}
