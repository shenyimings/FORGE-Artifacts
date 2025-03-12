//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library Allowlist {
    bytes32 internal constant ALLOWLIST_SLOT = bytes32(uint256(keccak256("river.state.allowlist")) - 1);

    struct Slot {
        mapping(address => uint256) value;
    }

    function get(address account) internal view returns (uint256) {
        bytes32 slot = ALLOWLIST_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value[account];
    }

    function set(address account, uint256 status) internal {
        bytes32 slot = ALLOWLIST_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value[account] = status;
    }
}
