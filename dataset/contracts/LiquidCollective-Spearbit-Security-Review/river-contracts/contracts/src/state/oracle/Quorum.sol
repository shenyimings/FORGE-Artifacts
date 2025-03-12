//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library Quorum {
    bytes32 internal constant QUORUM_SLOT = bytes32(uint256(keccak256("river.state.quorum")) - 1);

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(QUORUM_SLOT);
    }

    function set(uint256 newValue) internal {
        return UnstructuredStorage.setStorageUint256(QUORUM_SLOT, newValue);
    }
}
