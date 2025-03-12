//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/TLC.1.sol";
import "../../../src/state/tlc/VestingSchedules.2.sol";
import {ITransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract VestingSchedulesMigrationV1ToV2 is Test {
    bool internal _skip = false;

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, 16000000);
            console.log("1.vestingSchedulesMigrationV1toV2.t.sol is active");
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    address internal constant TLC_MAINNET_ADDRESS = 0xb5Fe6946836D687848B5aBd42dAbF531d5819632;
    address internal constant TLC_MAINNET_PROXY_ADMIN_ADDRESS = 0x0D1dE267015a75F5069fD1c9ed382210B3002cEb;

    function test_migration() external shouldSkip {
        TUPProxy tlcProxy = TUPProxy(payable(TLC_MAINNET_ADDRESS));

        TLCV1 newImplementation = new TLCV1();

        vm.prank(TLC_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(tlcProxy)).upgradeToAndCall(
            address(newImplementation), abi.encodeWithSelector(TLCV1.migrateVestingSchedules.selector)
        );

        TLCV1 tlc = TLCV1(TLC_MAINNET_ADDRESS);

        VestingSchedulesV2.VestingSchedule[] memory expectedVestingSchedules = getExpectedVestingSchedules();
        uint256 count = tlc.getVestingScheduleCount();

        assertEq(count, expectedVestingSchedules.length);

        for (uint256 idx = 0; idx < tlc.getVestingScheduleCount(); ++idx) {
            VestingSchedulesV2.VestingSchedule memory vs = tlc.getVestingSchedule(idx);

            assertEq(vs.start, expectedVestingSchedules[idx].start);
            assertEq(vs.end, expectedVestingSchedules[idx].end);
            assertEq(vs.cliffDuration, expectedVestingSchedules[idx].cliffDuration);
            assertEq(vs.lockDuration, expectedVestingSchedules[idx].lockDuration);
            assertEq(vs.duration, expectedVestingSchedules[idx].duration);
            assertEq(vs.periodDuration, expectedVestingSchedules[idx].periodDuration);
            assertEq(vs.amount, expectedVestingSchedules[idx].amount);
            assertEq(vs.creator, expectedVestingSchedules[idx].creator);
            assertEq(vs.beneficiary, expectedVestingSchedules[idx].beneficiary);
            assertEq(vs.revocable, expectedVestingSchedules[idx].revocable);
            assertEq(vs.releasedAmount, expectedVestingSchedules[idx].releasedAmount);
        }
    }

    // these vesting schedule values have been manually fetched and inserted
    function getExpectedVestingSchedules() internal pure returns (VestingSchedulesV2.VestingSchedule[] memory vs) {
        vs = new VestingSchedulesV2.VestingSchedule[](14);
        vs[0].start = 1653264000;
        vs[0].end = 1779494400;
        vs[0].cliffDuration = 31557600;
        vs[0].lockDuration = 45964800;
        vs[0].duration = 126230400;
        vs[0].periodDuration = 2629800;
        vs[0].amount = 40000000000000000000000000;
        vs[0].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[0].beneficiary = 0x51C83234DcCB29c025cf8486297C62647a3ce3e1;
        vs[0].revocable = true;
        vs[0].releasedAmount = 0;

        vs[1].start = 1653264000;
        vs[1].end = 1779494400;
        vs[1].cliffDuration = 31557600;
        vs[1].lockDuration = 45964800;
        vs[1].duration = 126230400;
        vs[1].periodDuration = 2629800;
        vs[1].amount = 10000000000000000000000000;
        vs[1].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[1].beneficiary = 0xB224788B28B8B5E2bC2783AF358558D4D9C8BB24;
        vs[1].revocable = true;
        vs[1].releasedAmount = 0;

        vs[2].start = 1653264000;
        vs[2].end = 1779494400;
        vs[2].cliffDuration = 31557600;
        vs[2].lockDuration = 45964800;
        vs[2].duration = 126230400;
        vs[2].periodDuration = 2629800;
        vs[2].amount = 40000000000000000000000000;
        vs[2].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[2].beneficiary = 0x2ef55866f1570a7aC2b0E8536f43B3C739A1cdeD;
        vs[2].revocable = true;
        vs[2].releasedAmount = 0;

        vs[3].start = 1653264000;
        vs[3].end = 1779494400;
        vs[3].cliffDuration = 31557600;
        vs[3].lockDuration = 45964800;
        vs[3].duration = 126230400;
        vs[3].periodDuration = 2629800;
        vs[3].amount = 30000000000000000000000000;
        vs[3].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[3].beneficiary = 0x9587fb56B23aEEEd2e825eB8D1caf0cd2Ed6b6eE;
        vs[3].revocable = true;
        vs[3].releasedAmount = 0;

        vs[4].start = 1653264000;
        vs[4].end = 1779494400;
        vs[4].cliffDuration = 31557600;
        vs[4].lockDuration = 45964800;
        vs[4].duration = 126230400;
        vs[4].periodDuration = 2629800;
        vs[4].amount = 10000000000000000000000000;
        vs[4].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[4].beneficiary = 0x29f7245E160333fC037a3f4aB5Bb436eDcEBdD82;
        vs[4].revocable = true;
        vs[4].releasedAmount = 0;

        vs[5].start = 1653264000;
        vs[5].end = 1779494400;
        vs[5].cliffDuration = 31557600;
        vs[5].lockDuration = 45964800;
        vs[5].duration = 126230400;
        vs[5].periodDuration = 2629800;
        vs[5].amount = 7500000000000000000000000;
        vs[5].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[5].beneficiary = 0x651338c448031d023DfC1166eaF4CA0B6Ca0e06a;
        vs[5].revocable = true;
        vs[5].releasedAmount = 0;

        vs[6].start = 1653264000;
        vs[6].end = 1779494400;
        vs[6].cliffDuration = 31557600;
        vs[6].lockDuration = 45964800;
        vs[6].duration = 126230400;
        vs[6].periodDuration = 2629800;
        vs[6].amount = 5000000000000000000000000;
        vs[6].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[6].beneficiary = 0x331C71B6aFAe92C50bcC396CcE861067C995649B;
        vs[6].revocable = true;
        vs[6].releasedAmount = 0;

        vs[7].start = 1658707200;
        vs[7].end = 1784937600;
        vs[7].cliffDuration = 31557600;
        vs[7].lockDuration = 40521600;
        vs[7].duration = 126230400;
        vs[7].periodDuration = 2629800;
        vs[7].amount = 2500000000000000000000000;
        vs[7].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[7].beneficiary = 0xFB94Dd18969eA93D9efAf0149A502bA1a0dA722b;
        vs[7].revocable = true;
        vs[7].releasedAmount = 0;

        vs[8].start = 1663545600;
        vs[8].end = 1789776000;
        vs[8].cliffDuration = 31557600;
        vs[8].lockDuration = 35683200;
        vs[8].duration = 126230400;
        vs[8].periodDuration = 2629800;
        vs[8].amount = 4000000000000000000000000;
        vs[8].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[8].beneficiary = 0x6E4841F40De60a49ea0c76a59D50d07108d8825e;
        vs[8].revocable = true;
        vs[8].releasedAmount = 0;

        vs[9].start = 1656633600;
        vs[9].end = 1782864000;
        vs[9].cliffDuration = 31557600;
        vs[9].lockDuration = 42595200;
        vs[9].duration = 126230400;
        vs[9].periodDuration = 2629800;
        vs[9].amount = 45000000000000000000000000;
        vs[9].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[9].beneficiary = 0x62B90F4F6d1DFA5d19eb725C8dD823e8FAf35E3a;
        vs[9].revocable = true;
        vs[9].releasedAmount = 0;

        vs[10].start = 1656633600;
        vs[10].end = 1782864000;
        vs[10].cliffDuration = 31557600;
        vs[10].lockDuration = 42595200;
        vs[10].duration = 126230400;
        vs[10].periodDuration = 2629800;
        vs[10].amount = 42000000000000000000000000;
        vs[10].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[10].beneficiary = 0x911b2B97B47e46760988505c14AdF0A06BE22Beb;
        vs[10].revocable = true;
        vs[10].releasedAmount = 0;

        vs[11].start = 1656633600;
        vs[11].end = 1782864000;
        vs[11].cliffDuration = 31557600;
        vs[11].lockDuration = 42595200;
        vs[11].duration = 126230400;
        vs[11].periodDuration = 2629800;
        vs[11].amount = 40000000000000000000000000;
        vs[11].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[11].beneficiary = 0x8B733FE59d1190B3efA5bE3f21A574EF2aB0C62B;
        vs[11].revocable = true;
        vs[11].releasedAmount = 0;

        vs[12].start = 1656633600;
        vs[12].end = 1782864000;
        vs[12].cliffDuration = 31557600;
        vs[12].lockDuration = 42595200;
        vs[12].duration = 126230400;
        vs[12].periodDuration = 2629800;
        vs[12].amount = 14000000000000000000000000;
        vs[12].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[12].beneficiary = 0xb6C5b79ac4d91fbA8F2989f5Fd3Fd7aBdB0cCc71;
        vs[12].revocable = true;
        vs[12].releasedAmount = 0;

        vs[13].start = 1661990400;
        vs[13].end = 1725148800;
        vs[13].cliffDuration = 31579200;
        vs[13].lockDuration = 37238400;
        vs[13].duration = 63158400;
        vs[13].periodDuration = 2631600;
        vs[13].amount = 2500000000000000000000000;
        vs[13].creator = 0x070cbF96cac223D88401D6227577f9FA480C57C8;
        vs[13].beneficiary = 0x4873eD92C3ADd456b415d141eC3b961435676e44;
        vs[13].revocable = true;
        vs[13].releasedAmount = 0;
    }
}
