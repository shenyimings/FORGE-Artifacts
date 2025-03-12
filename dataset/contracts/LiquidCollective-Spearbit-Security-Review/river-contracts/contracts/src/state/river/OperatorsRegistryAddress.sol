//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";
import "../../libraries/Errors.sol";

library OperatorsRegistryAddress {
    bytes32 internal constant OPERATORS_REGISTRY_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.operatorsRegistryAddress")) - 1);

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(OPERATORS_REGISTRY_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        if (newValue == address(0)) {
            revert Errors.InvalidZeroAddress();
        }
        UnstructuredStorage.setStorageAddress(OPERATORS_REGISTRY_ADDRESS_SLOT, newValue);
    }
}
