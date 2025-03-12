//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title Keeper Address Storage
/// @notice Utility to manage the Keeper Address in storage
library KeeperAddress {
    /// @notice Storage slot of the Keeper Address
    bytes32 internal constant KEEPER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1);

    /// @notice Retrieve the Keeper Address
    /// @return The Keeper Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(KEEPER_ADDRESS_SLOT);
    }

    /// @notice Sets the Keeper Address
    /// @param _newValue New Keeper Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(KEEPER_ADDRESS_SLOT, _newValue);
    }
}
