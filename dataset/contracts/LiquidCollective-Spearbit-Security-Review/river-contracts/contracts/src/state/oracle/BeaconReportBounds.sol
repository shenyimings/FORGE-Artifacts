//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library BeaconReportBounds {
    // Lido Finance beacon spec data structure
    struct BeaconReportBoundsStruct {
        uint256 annualAprUpperBound;
        uint256 relativeLowerBound;
    }

    uint256 public constant DELTA_BASE = 10_000;

    bytes32 internal constant BEACON_REPORT_BOUNDS_SLOT =
        bytes32(uint256(keccak256("river.state.beaconReportBounds")) - 1);

    struct Slot {
        BeaconReportBoundsStruct value;
    }

    function get() internal view returns (BeaconReportBoundsStruct memory) {
        bytes32 slot = BEACON_REPORT_BOUNDS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(BeaconReportBoundsStruct memory newBeaconReportBounds) internal {
        bytes32 slot = BEACON_REPORT_BOUNDS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newBeaconReportBounds;
    }
}
