//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library WithdrawalCredentials {
    bytes32 internal constant WITHDRAWAL_CREDENTIALS_SLOT =
        bytes32(uint256(keccak256("river.state.withdrawalCredentials")) - 1);

    function get() internal view returns (bytes32) {
        return UnstructuredStorage.getStorageBytes32(WITHDRAWAL_CREDENTIALS_SLOT);
    }

    function set(bytes32 newValue) internal {
        UnstructuredStorage.setStorageBytes32(WITHDRAWAL_CREDENTIALS_SLOT, newValue);
    }
}
