//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library OperatorRewardsShare {
    bytes32 internal constant OPERATOR_REWARDS_SHARE_SLOT =
        bytes32(uint256(keccak256("river.state.operatorRewardsShare")) - 1);

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(OPERATOR_REWARDS_SHARE_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(OPERATOR_REWARDS_SHARE_SLOT, newValue);
    }
}
