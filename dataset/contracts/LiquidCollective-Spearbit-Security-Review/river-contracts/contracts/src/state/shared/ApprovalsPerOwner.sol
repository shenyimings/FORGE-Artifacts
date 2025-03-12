//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library ApprovalsPerOwner {
    bytes32 internal constant APPROVALS_PER_OWNER_SLOT =
        bytes32(uint256(keccak256("river.state.approvalsPerOwner")) - 1);

    struct Slot {
        mapping(address => mapping(address => uint256)) value;
    }

    function get(address owner, address operator) internal view returns (uint256) {
        bytes32 slot = APPROVALS_PER_OWNER_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value[owner][operator];
    }

    function set(address owner, address operator, uint256 newValue) internal {
        bytes32 slot = APPROVALS_PER_OWNER_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value[owner][operator] = newValue;
    }
}
