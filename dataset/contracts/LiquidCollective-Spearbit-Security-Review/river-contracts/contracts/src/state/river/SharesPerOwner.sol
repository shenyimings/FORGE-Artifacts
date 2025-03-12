//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library SharesPerOwner {
    bytes32 internal constant SHARES_SLOT = bytes32(uint256(keccak256("river.state.sharesPerOwner")) - 1);

    struct Slot {
        mapping(address => uint256) value;
    }

    function get(address owner) internal view returns (uint256) {
        bytes32 slot = SHARES_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value[owner];
    }

    function set(address owner, uint256 newValue) internal {
        bytes32 slot = SHARES_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value[owner] = newValue;
    }
}
