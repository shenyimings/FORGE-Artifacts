//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library DepositedValidatorCount {
    bytes32 internal constant DEPOSITED_VALIDATOR_COUNT_SLOT =
        bytes32(uint256(keccak256("river.state.depositedValidatorCount")) - 1);

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(DEPOSITED_VALIDATOR_COUNT_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(DEPOSITED_VALIDATOR_COUNT_SLOT, newValue);
    }
}
