//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title Denier Address Storage
/// @notice Utility to manage the Denier Address in storage
library DenierAddress {
    /// @notice Storage slot of the Denier Address
    bytes32 internal constant DENIER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.denierAddress")) - 1);

    /// @notice Retrieve the Denier Address
    /// @return The Denier Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(DENIER_ADDRESS_SLOT);
    }

    /// @notice Sets the Denier Address
    /// @param _newValue New Denier Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(DENIER_ADDRESS_SLOT, _newValue);
    }
}
