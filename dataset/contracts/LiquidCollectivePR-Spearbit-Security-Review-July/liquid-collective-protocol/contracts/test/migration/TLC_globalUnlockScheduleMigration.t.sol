//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../src/migration/TLC_globalUnlockScheduleMigration.sol";
import "../../src/TLC.1.sol";

contract TlcMigrationTest is Test {
    TlcMigration migrationsContract;
    TLCV1 tlc;
    string rpc;

    function setUp() public {
        rpc = vm.rpcUrl("mainnet");
    }

    function testCreate() public {
        migrationsContract = new TlcMigration();
    }

    function testGas() public {
        vm.createSelectFork(rpc, 18063740);

        migrationsContract = new TlcMigration();
        proxy tlcProxy = proxy(0xb5Fe6946836D687848B5aBd42dAbF531d5819632);
        vm.prank(0x0D1dE267015a75F5069fD1c9ed382210B3002cEb);
        tlcProxy.upgradeToAndCall(address(migrationsContract), abi.encodeWithSignature("migrate()"));
    }

    function testMigrate() public {
        // Significantly faster when cached locally, run a local fork for best perf (anvil recommended)
        vm.createSelectFork(rpc, 18063740);

        proxy tlcProxy = proxy(0xb5Fe6946836D687848B5aBd42dAbF531d5819632);
        assertEq(tlcProxy.getVestingScheduleCount(), 67);

        VestingSchedulesV2.VestingSchedule[] memory schedulesBefore = new VestingSchedulesV2.VestingSchedule[](67);
        for (uint256 i = 0; i < 67; i++) {
            schedulesBefore[i] = TLCV1(address(tlcProxy)).getVestingSchedule(i);
            //console.log("%s,%s,%s", i, schedulesBefore[i].start, schedulesBefore[i].end);
        }

        migrationsContract = new TlcMigration();
        vm.prank(0x0D1dE267015a75F5069fD1c9ed382210B3002cEb);
        tlcProxy.upgradeToAndCall(address(migrationsContract), abi.encodeWithSignature("migrate()"));

        tlc = new TLCV1();
        vm.prank(0x0D1dE267015a75F5069fD1c9ed382210B3002cEb);
        tlcProxy.upgradeTo(address(tlc));

        assertEq(tlcProxy.getVestingScheduleCount(), 67);

        // Check that the all the values that shouldn't change didn't
        for (uint256 i = 0; i < 67; i++) {
            VestingSchedulesV2.VestingSchedule memory schedule = TLCV1(address(tlcProxy)).getVestingSchedule(i);
            assertEq(schedule.amount, schedulesBefore[i].amount);
            assertEq(schedule.creator, schedulesBefore[i].creator);
            assertEq(schedule.beneficiary, schedulesBefore[i].beneficiary);
            assertEq(schedule.revocable, schedulesBefore[i].revocable);
            assertEq(schedule.releasedAmount, schedulesBefore[i].releasedAmount);
        }
        // Check that the value we should have changed did change
        // Schedule 0
        VestingSchedulesV2.VestingSchedule memory schedule = TLCV1(address(tlcProxy)).getVestingSchedule(0);
        assertEq(schedule.start, schedulesBefore[0].start);
        assertEq(schedule.end, schedulesBefore[0].end);
        assertEq(schedule.lockDuration, 75772800);
        assertEq(schedule.cliffDuration, schedulesBefore[0].cliffDuration);
        assertEq(schedule.duration, schedulesBefore[0].duration);
        assertEq(schedule.periodDuration, schedulesBefore[0].periodDuration);
        assertFalse(TLCV1(address(tlcProxy)).isGlobalUnlockedScheduleIgnored(0));

        // Schedule 17
        schedule = TLCV1(address(tlcProxy)).getVestingSchedule(17);
        assertEq(schedule.start, schedulesBefore[17].start);
        assertEq(schedule.end, schedulesBefore[17].end);
        assertEq(schedule.lockDuration, 53740800);
        assertEq(schedule.cliffDuration, schedulesBefore[17].cliffDuration);
        assertEq(schedule.duration, schedulesBefore[17].duration);
        assertEq(schedule.periodDuration, schedulesBefore[17].periodDuration);
        assertTrue(TLCV1(address(tlcProxy)).isGlobalUnlockedScheduleIgnored(17));

        // Schedule 36
        schedule = TLCV1(address(tlcProxy)).getVestingSchedule(36);
        assertEq(schedule.start, 1686175200);
        assertEq(schedule.end, 1686261600);
        assertEq(schedule.lockDuration, 42861600);
        assertEq(schedule.cliffDuration, schedulesBefore[36].cliffDuration);
        assertEq(schedule.duration, 86400);
        assertEq(schedule.periodDuration, 86400);
        assertFalse(TLCV1(address(tlcProxy)).isGlobalUnlockedScheduleIgnored(36));

        // Schedule 60
        schedule = TLCV1(address(tlcProxy)).getVestingSchedule(60);
        assertEq(schedule.start, 1686175200);
        assertEq(schedule.end, 1686261600);
        assertEq(schedule.lockDuration, 42861600);
        assertEq(schedule.cliffDuration, schedulesBefore[60].cliffDuration);
        assertEq(schedule.duration, 86400);
        assertEq(schedule.periodDuration, 86400);
        assertFalse(TLCV1(address(tlcProxy)).isGlobalUnlockedScheduleIgnored(60));

        // Schedule 66
        schedule = TLCV1(address(tlcProxy)).getVestingSchedule(66);
        assertEq(schedule.start, schedulesBefore[66].start);
        assertEq(schedule.end, schedulesBefore[66].end);
        assertEq(schedule.lockDuration, 38188800);
        assertEq(schedule.cliffDuration, schedulesBefore[66].cliffDuration);
        assertEq(schedule.duration, schedulesBefore[66].duration);
        assertEq(schedule.periodDuration, schedulesBefore[66].periodDuration);
        assertTrue(TLCV1(address(tlcProxy)).isGlobalUnlockedScheduleIgnored(66));
    }
}

interface proxy {
    function admin() external view returns (address);
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata cdata) external payable;
    function migrate() external;
    function getVestingScheduleCount() external view returns (uint256);
    function getMigrationCount() external view returns (uint256);
}
