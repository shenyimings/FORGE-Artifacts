//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../../src/state/tlc/VestingSchedules.1.sol";
import "../../../src/state/tlc/VestingSchedules.2.sol";
import "forge-std/Test.sol";

contract VestingSchedulesMigrationTest is Test {
    address internal alice;
    address internal bob;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function _createV1VestingSchedule(VestingSchedulesV1.VestingSchedule memory vestingSchedule)
        internal
        returns (uint256)
    {
        // Create a V1 schedule
        return VestingSchedulesV1.push(vestingSchedule) - 1;
    }

    function _updateV2VestingSchedule(uint256 index, VestingSchedulesV2.VestingSchedule memory newVestingSchedule)
        internal
        returns (bool)
    {
        VestingSchedulesV2.VestingSchedule storage vestingScheduleV2 = VestingSchedulesV2.get(index);

        vestingScheduleV2.start = newVestingSchedule.start;
        vestingScheduleV2.end = newVestingSchedule.end;
        vestingScheduleV2.lockDuration = newVestingSchedule.lockDuration;
        vestingScheduleV2.cliffDuration = newVestingSchedule.cliffDuration;
        vestingScheduleV2.duration = newVestingSchedule.duration;
        vestingScheduleV2.periodDuration = newVestingSchedule.periodDuration;
        vestingScheduleV2.amount = newVestingSchedule.amount;
        vestingScheduleV2.creator = newVestingSchedule.creator;
        vestingScheduleV2.beneficiary = newVestingSchedule.beneficiary;
        vestingScheduleV2.revocable = newVestingSchedule.revocable;
        vestingScheduleV2.releasedAmount = newVestingSchedule.releasedAmount;

        return true;
    }

    function _migrate() internal returns (uint256) {
        if (VestingSchedulesV2.getCount() == 0) {
            uint256 existingV1VestingSchedules = VestingSchedulesV1.getCount();
            for (uint256 idx; idx < existingV1VestingSchedules;) {
                VestingSchedulesV2.migrateVestingScheduleFromV1(idx, 0);
                unchecked {
                    ++idx;
                }
            }
        }
        return VestingSchedulesV2.getCount();
    }

    function testVestingScheduleV1ToV2Compatibility(
        uint64 _start,
        uint64 _end,
        uint32 _duration,
        uint32 _periodDuration,
        uint32 _cliffDuration,
        uint32 _lockDuration,
        bool _revocable,
        uint256 _amount,
        uint256 _releasedAmount
    ) public {
        // #1. Create two V1 schedule
        VestingSchedulesV1.VestingSchedule memory vestingScheduleV1 = VestingSchedulesV1.VestingSchedule({
            start: _start,
            end: _end,
            lockDuration: _lockDuration,
            cliffDuration: _cliffDuration,
            duration: _duration,
            periodDuration: _periodDuration,
            amount: _amount,
            creator: bob,
            beneficiary: alice,
            revocable: _revocable
        });

        vm.startPrank(bob);
        _createV1VestingSchedule(vestingScheduleV1);
        _createV1VestingSchedule(vestingScheduleV1);
        vm.stopPrank();

        // #2. Migrate from v1 to v2
        vm.startPrank(bob);
        uint256 count = _migrate();
        vm.stopPrank();

        assert(count == 2);

        // #3. Get v2 schedules and check validity of inputs
        for (uint256 idx = 0; idx < count;) {
            VestingSchedulesV2.VestingSchedule memory vestingScheduleV2 = VestingSchedulesV2.get(idx);
            assert(vestingScheduleV2.start == vestingScheduleV1.start);
            assert(vestingScheduleV2.end == vestingScheduleV1.end);
            assert(vestingScheduleV2.cliffDuration == vestingScheduleV1.cliffDuration);
            assert(vestingScheduleV2.lockDuration == vestingScheduleV1.lockDuration);
            assert(vestingScheduleV2.periodDuration == vestingScheduleV1.periodDuration);
            assert(vestingScheduleV2.amount == vestingScheduleV1.amount);
            assert(vestingScheduleV2.creator == vestingScheduleV1.creator);
            assert(vestingScheduleV2.beneficiary == vestingScheduleV1.beneficiary);
            assert(vestingScheduleV2.revocable == vestingScheduleV1.revocable);
            assert(vestingScheduleV2.releasedAmount == 0);
            unchecked {
                ++idx;
            }
        }

        // Arguments are mixed on purpose to increase fuzzing variability
        VestingSchedulesV2.VestingSchedule memory newVestingScheduleV2 = VestingSchedulesV2.VestingSchedule({
            start: _end,
            end: _start,
            lockDuration: _cliffDuration,
            cliffDuration: _lockDuration,
            duration: _periodDuration,
            periodDuration: _duration,
            amount: _releasedAmount,
            creator: bob,
            beneficiary: alice,
            revocable: _start % 2 == 0,
            releasedAmount: _amount
        });

        // #3. Update V2 schedule
        for (uint256 idx = 0; idx < count;) {
            assert(_updateV2VestingSchedule(idx, newVestingScheduleV2));
            unchecked {
                ++idx;
            }
        }

        // #4. Verify V2 schedule have been updated properly
        for (uint256 idx = 0; idx < count;) {
            VestingSchedulesV2.VestingSchedule memory vestingScheduleV2 = VestingSchedulesV2.get(idx);
            assert(vestingScheduleV2.start == newVestingScheduleV2.start);
            assert(vestingScheduleV2.end == newVestingScheduleV2.end);
            assert(vestingScheduleV2.cliffDuration == newVestingScheduleV2.cliffDuration);
            assert(vestingScheduleV2.lockDuration == newVestingScheduleV2.lockDuration);
            assert(vestingScheduleV2.periodDuration == newVestingScheduleV2.periodDuration);
            assert(vestingScheduleV2.amount == newVestingScheduleV2.amount);
            assert(vestingScheduleV2.creator == newVestingScheduleV2.creator);
            assert(vestingScheduleV2.beneficiary == newVestingScheduleV2.beneficiary);
            assert(vestingScheduleV2.revocable == newVestingScheduleV2.revocable);
            assert(vestingScheduleV2.releasedAmount == newVestingScheduleV2.releasedAmount);
            unchecked {
                ++idx;
            }
        }
    }
}
