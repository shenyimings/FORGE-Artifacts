//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library Shares {
    bytes32 internal constant SHARES_SLOT = bytes32(uint256(keccak256("river.state.shares")) - 1);

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(SHARES_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(SHARES_SLOT, newValue);
    }
}
