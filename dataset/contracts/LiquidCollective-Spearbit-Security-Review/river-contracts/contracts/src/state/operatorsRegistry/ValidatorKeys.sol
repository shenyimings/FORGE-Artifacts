//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/BytesLib.sol";

library ValidatorKeys {
    uint256 internal constant PUBLIC_KEY_LENGTH = 48;
    uint256 internal constant SIGNATURE_LENGTH = 96;

    error InvalidPublicKey();
    error InvalidSignature();

    bytes32 internal constant VALIDATOR_KEYS_SLOT = bytes32(uint256(keccak256("river.state.validatorKeys")) - 1);

    struct Slot {
        mapping(uint256 => mapping(uint256 => bytes)) value;
    }

    function get(uint256 operatorIndex, uint256 idx)
        internal
        view
        returns (bytes memory publicKey, bytes memory signature)
    {
        bytes32 slot = VALIDATOR_KEYS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        bytes storage entry = r.value[operatorIndex][idx];

        publicKey = BytesLib.slice(entry, 0, PUBLIC_KEY_LENGTH);
        signature = BytesLib.slice(entry, PUBLIC_KEY_LENGTH, SIGNATURE_LENGTH);
    }

    function getKeys(uint256 operatorIndex, uint256 startIdx, uint256 amount)
        internal
        view
        returns (bytes[] memory publicKey, bytes[] memory signatures)
    {
        publicKey = new bytes[](amount);
        signatures = new bytes[](amount);

        bytes32 slot = VALIDATOR_KEYS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        for (uint256 idx = startIdx; idx < startIdx + amount;) {
            bytes memory rawCredentials = r.value[operatorIndex][idx];
            publicKey[idx - startIdx] = BytesLib.slice(rawCredentials, 0, PUBLIC_KEY_LENGTH);
            signatures[idx - startIdx] = BytesLib.slice(rawCredentials, PUBLIC_KEY_LENGTH, SIGNATURE_LENGTH);
            unchecked {
                ++idx;
            }
        }
    }

    function set(uint256 operatorIndex, uint256 idx, bytes memory publicKey, bytes memory signature) internal {
        bytes memory concatenatedKeys = BytesLib.concat(publicKey, signature);

        bytes32 slot = VALIDATOR_KEYS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value[operatorIndex][idx] = concatenatedKeys;
    }
}
