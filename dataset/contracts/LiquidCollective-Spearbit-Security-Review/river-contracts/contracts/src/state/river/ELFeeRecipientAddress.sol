//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library ELFeeRecipientAddress {
    bytes32 internal constant EL_FEE_RECIPIENT_ADDRESS =
        bytes32(uint256(keccak256("river.state.elFeeRecipientAddress")) - 1);

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(EL_FEE_RECIPIENT_ADDRESS);
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(EL_FEE_RECIPIENT_ADDRESS, newValue);
    }
}
