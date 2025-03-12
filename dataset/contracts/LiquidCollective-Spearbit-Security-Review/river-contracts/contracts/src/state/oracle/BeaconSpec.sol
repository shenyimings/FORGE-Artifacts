//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library BeaconSpec {
    // Lido Finance beacon spec data structure
    struct BeaconSpecStruct {
        uint64 epochsPerFrame;
        uint64 slotsPerEpoch;
        uint64 secondsPerSlot;
        uint64 genesisTime;
    }

    bytes32 internal constant BEACON_SPEC_SLOT = bytes32(uint256(keccak256("river.state.beaconSpec")) - 1);

    struct Slot {
        BeaconSpecStruct value;
    }

    function get() internal view returns (BeaconSpecStruct memory) {
        bytes32 slot = BEACON_SPEC_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(BeaconSpecStruct memory newBeaconSpec) internal {
        bytes32 slot = BEACON_SPEC_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newBeaconSpec;
    }
}
