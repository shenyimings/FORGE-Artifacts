//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";
import "../../libraries/Errors.sol";

library OracleAddress {
    bytes32 internal constant ORACLE_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.oracleAddress")) - 1);

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(ORACLE_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        if (newValue == address(0)) {
            revert Errors.InvalidZeroAddress();
        }
        UnstructuredStorage.setStorageAddress(ORACLE_ADDRESS_SLOT, newValue);
    }
}
