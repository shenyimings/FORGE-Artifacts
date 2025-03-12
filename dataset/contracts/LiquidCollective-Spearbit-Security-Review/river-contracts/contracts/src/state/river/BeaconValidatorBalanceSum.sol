//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library BeaconValidatorBalanceSum {
    bytes32 internal constant VALIDATOR_BALANCE_SUM_SLOT =
        bytes32(uint256(keccak256("river.state.beaconValidatorBalanceSum")) - 1);

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(VALIDATOR_BALANCE_SUM_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(VALIDATOR_BALANCE_SUM_SLOT, newValue);
    }
}
