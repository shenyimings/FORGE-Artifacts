//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library ReportsVariants {
    uint256 internal constant COUNT_OUTMASK = 0xFFFFFFFFFFFFFFFFFFFFFFFF0000;

    bytes32 internal constant REPORTS_VARIANTS_SLOT = bytes32(uint256(keccak256("river.state.reportsVariants")) - 1);

    struct Slot {
        uint256[] value;
    }

    function get() internal view returns (uint256[] memory) {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(uint256 idx, uint256 val) internal {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value[idx] = val;
    }

    function push(uint256 variant) internal {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value.push(variant);
    }

    function indexOfReport(uint256 variant) internal view returns (int256) {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        for (uint256 idx = 0; idx < r.value.length;) {
            if (r.value[idx] & COUNT_OUTMASK == variant) {
                return int256(idx);
            }
            unchecked {
                ++idx;
            }
        }

        return int256(-1);
    }

    function clear() internal {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        delete r.value;
    }
}
