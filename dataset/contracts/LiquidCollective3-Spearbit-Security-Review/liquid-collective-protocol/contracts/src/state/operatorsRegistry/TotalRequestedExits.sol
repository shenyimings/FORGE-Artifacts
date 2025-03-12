//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title TotalRequestedExits Storage
/// @notice Utility to manage the TotalRequestedExits in storage
library TotalRequestedExits {
    /// @notice Storage slot of the TotalRequestedExits
    bytes32 internal constant TOTAL_REQUESTED_EXITS_SLOT =
        bytes32(uint256(keccak256("river.state.TotalRequestedExits")) - 1);

    /// @notice Retrieve the TotalRequestedExits
    /// @return The TotalRequestedExits
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(TOTAL_REQUESTED_EXITS_SLOT);
    }

    /// @notice Sets the TotalRequestedExits
    /// @param _newValue New TotalRequestedExits
    function set(uint256 _newValue) internal {
        return LibUnstructuredStorage.setStorageUint256(TOTAL_REQUESTED_EXITS_SLOT, _newValue);
    }
}
