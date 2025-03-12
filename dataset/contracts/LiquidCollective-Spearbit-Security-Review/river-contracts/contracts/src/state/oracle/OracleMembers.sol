//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library OracleMembers {
    bytes32 internal constant ORACLE_MEMBERS_SLOT = bytes32(uint256(keccak256("river.state.oracleMembers")) - 1);

    struct Slot {
        address[] value;
    }

    function get() internal view returns (address[] memory) {
        bytes32 slot = ORACLE_MEMBERS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function push(address newOracleMember) internal {
        bytes32 slot = ORACLE_MEMBERS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value.push(newOracleMember);
    }

    function indexOf(address memberAddress) internal view returns (int256) {
        bytes32 slot = ORACLE_MEMBERS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        for (uint256 idx = 0; idx < r.value.length;) {
            if (r.value[idx] == memberAddress) {
                return int256(idx);
            }
            unchecked {
                ++idx;
            }
        }

        return int256(-1);
    }

    function deleteItem(uint256 idx) internal {
        bytes32 slot = ORACLE_MEMBERS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        uint256 lastIdx = r.value.length - 1;
        if (lastIdx != idx) {
            r.value[idx] = r.value[lastIdx];
        }

        r.value.pop();
    }
}
