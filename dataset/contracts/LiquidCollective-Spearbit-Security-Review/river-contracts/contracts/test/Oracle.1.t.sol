//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/Oracle.1.sol";
import "../src/libraries/Errors.sol";
import "../src/Withdraw.1.sol";
import "./utils/River.setup1.sol";
import "./utils/UserFactory.sol";
import "./mocks/RiverMock.sol";
import "../src/interfaces/IRiver.1.sol";

contract OracleV1Tests {
    OracleV1 internal oracle;

    IRiverV1 internal oracleInput;
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    UserFactory internal uf = new UserFactory();

    address internal admin = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);

    address internal oracleOne = address(0x7fe52bbF4D779cA115231b604637d5f80bab2C40);
    address internal oracleTwo = address(0xb479DE67E0827Cc72bf5c1727e3bf6fe15007554);

    uint64 internal constant EPOCHS_PER_FRAME = 225;
    uint64 internal constant SLOTS_PER_EPOCH = 32;
    uint64 internal constant SECONDS_PER_SLOT = 12;
    uint64 internal constant GENESIS_TIME = 1606824023;

    uint256 internal constant UPPER_BOUND = 1000;
    uint256 internal constant LOWER_BOUND = 500;

    function setUp() public {
        oracleInput = IRiverV1(payable(address(new RiverMock())));
        oracle = new OracleV1();
        oracle.initOracleV1(
            address(oracleInput),
            admin,
            EPOCHS_PER_FRAME,
            SLOTS_PER_EPOCH,
            SECONDS_PER_SLOT,
            GENESIS_TIME,
            UPPER_BOUND,
            LOWER_BOUND
        );

        vm.startPrank(admin);
        oracle.setQuorum(2);
        vm.stopPrank();
    }

    function testGetAdmin() public view {
        assert(oracle.getAdministrator() == admin);
    }

    function testGetRiver() public view {
        assert(oracle.getRiver() == address(oracleInput));
    }

    function testGetTime(uint256 time) public {
        vm.warp(time);
        assert(oracle.getTime() == time);
    }

    function testGetEpochId(uint32 epochId) public {
        vm.warp(GENESIS_TIME + (epochId * SECONDS_PER_SLOT * SLOTS_PER_EPOCH));
        assert(oracle.getCurrentEpochId() == epochId);
    }

    function testGetFrameFirst(uint32 epochId) public {
        uint256 frameFirst = (epochId / EPOCHS_PER_FRAME) * EPOCHS_PER_FRAME;
        vm.warp(GENESIS_TIME + (epochId * SECONDS_PER_SLOT * SLOTS_PER_EPOCH));
        assert(oracle.getFrameFirstEpochId(epochId) == frameFirst);
    }

    function testAddMember(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        oracle.addMember(newMember);
        assert(oracle.isMember(newMember) == true);
    }

    function testAddMemberUnauthorized(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(newMember);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", newMember));
        oracle.addMember(newMember);
    }

    function testAddMemberExisting(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        oracle.addMember(newMember);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        oracle.addMember(newMember);
    }

    function testRemoveMember(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        oracle.addMember(newMember);
        assert(oracle.isMember(newMember) == true);
        oracle.removeMember(newMember);
        assert(oracle.isMember(newMember) == false);
    }

    function testRemoveMemberUnauthorized(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        oracle.addMember(newMember);
        assert(oracle.isMember(newMember) == true);
        vm.stopPrank();
        vm.startPrank(newMember);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", newMember));
        oracle.removeMember(newMember);
    }

    function testSetBeaconSpec(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    )
        public
    {
        BeaconSpec.BeaconSpecStruct memory bs = oracle.getBeaconSpec();
        assert(bs.epochsPerFrame == EPOCHS_PER_FRAME);
        assert(bs.slotsPerEpoch == SLOTS_PER_EPOCH);
        assert(bs.secondsPerSlot == SECONDS_PER_SLOT);
        assert(bs.genesisTime == GENESIS_TIME);

        vm.startPrank(admin);
        oracle.setBeaconSpec(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime);

        bs = oracle.getBeaconSpec();
        assert(bs.epochsPerFrame == _epochsPerFrame);
        assert(bs.slotsPerEpoch == _slotsPerEpoch);
        assert(bs.secondsPerSlot == _secondsPerSlot);
        assert(bs.genesisTime == _genesisTime);
    }

    function testSetBeaconSpecUnauthorized(
        uint256 _intruderSalt,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    )
        public
    {
        address _intruder = uf._new(_intruderSalt);
        BeaconSpec.BeaconSpecStruct memory bs = oracle.getBeaconSpec();
        assert(bs.epochsPerFrame == EPOCHS_PER_FRAME);
        assert(bs.slotsPerEpoch == SLOTS_PER_EPOCH);
        assert(bs.secondsPerSlot == SECONDS_PER_SLOT);
        assert(bs.genesisTime == GENESIS_TIME);

        vm.startPrank(_intruder);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", _intruder));
        oracle.setBeaconSpec(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime);
    }

    function testSetBeaconBounds(uint256 _up, uint64 _down) public {
        BeaconReportBounds.BeaconReportBoundsStruct memory bounds = oracle.getBeaconBounds();
        assert(bounds.annualAprUpperBound == UPPER_BOUND);
        assert(bounds.relativeLowerBound == LOWER_BOUND);
        vm.startPrank(admin);
        oracle.setBeaconBounds(_up, _down);

        bounds = oracle.getBeaconBounds();
        assert(bounds.annualAprUpperBound == _up);
        assert(bounds.relativeLowerBound == _down);
    }

    function testSetBeaconBoundsUnauthorized(uint256 _intruderSalt, uint256 _up, uint64 _down) public {
        address _intruder = uf._new(_intruderSalt);
        BeaconReportBounds.BeaconReportBoundsStruct memory bounds = oracle.getBeaconBounds();
        assert(bounds.annualAprUpperBound == UPPER_BOUND);
        assert(bounds.relativeLowerBound == LOWER_BOUND);

        vm.startPrank(_intruder);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", _intruder));
        oracle.setBeaconBounds(_up, _down);
    }

    function testReportBeaconEpochTooOld(uint256 oracleMemberSalt, uint64 timeFromGenesis) public {
        address oracleMember = uf._new(oracleMemberSalt);
        vm.warp(uint256(GENESIS_TIME) + uint256(timeFromGenesis));
        vm.startPrank(admin);
        oracle.addMember(oracleMember);
        oracle.setQuorum(1);
        vm.stopPrank();

        uint256 epochId = oracle.getCurrentEpochId();

        uint256 frameFirstEpochId = oracle.getFrameFirstEpochId(epochId);
        if (frameFirstEpochId > 0) {
            vm.startPrank(oracleMember);
            oracle.reportBeacon(frameFirstEpochId, 0, 0);
            uint256 oldFrameFirstEpochId = oracle.getFrameFirstEpochId(frameFirstEpochId + EPOCHS_PER_FRAME - 1);
            vm.expectRevert(
                abi.encodeWithSignature("EpochTooOld(uint256,uint256)", oldFrameFirstEpochId, frameFirstEpochId + EPOCHS_PER_FRAME)
            );
            oracle.reportBeacon(oldFrameFirstEpochId, 0, 0);
        }
    }

    function testReportBeaconNotFrameFirst(uint256 oracleMemberSalt, uint64 timeFromGenesis) public {
        address oracleMember = uf._new(oracleMemberSalt);
        vm.warp(uint256(GENESIS_TIME) + uint256(timeFromGenesis));
        vm.startPrank(admin);
        oracle.addMember(oracleMember);
        oracle.setQuorum(1);
        vm.stopPrank();

        uint256 epochId = oracle.getCurrentEpochId();

        uint256 frameFirstEpochId = oracle.getFrameFirstEpochId(epochId);
        if (frameFirstEpochId > 0) {
            vm.startPrank(oracleMember);
            vm.expectRevert(
                abi.encodeWithSignature("NotFrameFirstEpochId(uint256,uint256)", frameFirstEpochId - 1, frameFirstEpochId)
            );
            oracle.reportBeacon(frameFirstEpochId - 1, 0, 0);
        }
    }

    function testReportBeaconUnauthorized(uint256 oracleMemberSalt, uint64 timeFromGenesis) public {
        address oracleMember = uf._new(oracleMemberSalt);
        vm.warp(uint256(GENESIS_TIME) + uint256(timeFromGenesis));
        vm.startPrank(admin);
        oracle.setQuorum(1);
        vm.stopPrank();

        uint256 epochId = oracle.getCurrentEpochId();

        uint256 frameFirstEpochId = oracle.getFrameFirstEpochId(epochId);
        if (frameFirstEpochId > 0) {
            vm.startPrank(oracleMember);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", oracleMember));
            oracle.reportBeacon(frameFirstEpochId, 0, 0);
        }
    }

    function testReportBeaconTwice(uint256 oracleMemberSalt, uint64 timeFromGenesis) public {
        address oracleMember = uf._new(oracleMemberSalt);
        vm.warp(uint256(GENESIS_TIME) + uint256(timeFromGenesis));
        vm.startPrank(admin);
        oracle.addMember(oracleMember);
        address secondOracleMember;
        unchecked {
            secondOracleMember = address(uint160(oracleMember) + 1);
        }
        oracle.addMember(secondOracleMember);
        oracle.setQuorum(3);
        vm.stopPrank();

        uint256 epochId = oracle.getCurrentEpochId();

        uint256 frameFirstEpochId = oracle.getFrameFirstEpochId(epochId);
        if (frameFirstEpochId > 0) {
            vm.startPrank(oracleMember);
            oracle.reportBeacon(frameFirstEpochId, 0, 0);
            vm.expectRevert(
                abi.encodeWithSignature("AlreadyReported(uint256,address)", frameFirstEpochId, oracleMember)
            );
            oracle.reportBeacon(frameFirstEpochId, 0, 0);
            vm.stopPrank();
            vm.startPrank(secondOracleMember);
            oracle.reportBeacon(frameFirstEpochId, 0, 0);
            vm.expectRevert(
                abi.encodeWithSignature("AlreadyReported(uint256,address)", frameFirstEpochId, secondOracleMember)
            );
            oracle.reportBeacon(frameFirstEpochId, 0, 0);
            vm.stopPrank();
        }
    }

    function testReportBeacon(uint64 timeFromGenesis, uint64 balanceSum, uint32 validatorCount) public {
        RiverMock(address(oracleInput)).sudoSetTotalShares(1e9 * uint256(balanceSum));
        RiverMock(address(oracleInput)).sudoSetTotalSupply(1e9 * uint256(balanceSum));

        vm.warp(uint256(GENESIS_TIME) + uint256(timeFromGenesis));
        vm.startPrank(admin);
        oracle.addMember(oracleOne);
        oracle.addMember(oracleTwo);
        vm.stopPrank();

        uint256 epochId = oracle.getCurrentEpochId();

        uint256 frameFirstEpochId = oracle.getFrameFirstEpochId(epochId);
        if (frameFirstEpochId > 0) {
            assert(RiverMock(address(oracleInput)).validatorBalanceSum() == 0);
            assert(RiverMock(address(oracleInput)).validatorCount() == 0);
            assert(oracle.getExpectedEpochId() == 0);
            assert(oracle.getMemberReportStatus(oracleOne) == false);
            assert(oracle.getMemberReportStatus(oracleTwo) == false);

            vm.startPrank(oracleOne);
            oracle.reportBeacon(frameFirstEpochId, balanceSum, validatorCount);
            vm.stopPrank();

            assert(RiverMock(address(oracleInput)).validatorBalanceSum() == 0);
            assert(RiverMock(address(oracleInput)).validatorCount() == 0);
            assert(oracle.getExpectedEpochId() == frameFirstEpochId);
            assert(oracle.getMemberReportStatus(oracleOne) == true);
            assert(oracle.getMemberReportStatus(oracleTwo) == false);

            vm.startPrank(oracleTwo);
            oracle.reportBeacon(frameFirstEpochId, balanceSum, validatorCount);
            vm.stopPrank();

            assert(RiverMock(address(oracleInput)).validatorBalanceSum() == uint256(balanceSum) * 1e9);
            assert(RiverMock(address(oracleInput)).validatorCount() == validatorCount);
            assert(oracle.getExpectedEpochId() == frameFirstEpochId + EPOCHS_PER_FRAME);
            assert(oracle.getMemberReportStatus(oracleOne) == false);
            assert(oracle.getMemberReportStatus(oracleTwo) == false);
        }
    }

    function testBreakingUpperBoundLimit(uint64 timeFromGenesis, uint64 balanceSum, uint32 validatorCount) public {
        RiverMock(address(oracleInput)).sudoSetTotalShares(1e9 * uint256(balanceSum));
        RiverMock(address(oracleInput)).sudoSetTotalSupply(1e9 * uint256(balanceSum));

        vm.warp(uint256(GENESIS_TIME) + uint256(timeFromGenesis));
        vm.startPrank(admin);
        oracle.addMember(oracleOne);
        oracle.setQuorum(1);
        vm.stopPrank();

        uint256 epochId = oracle.getCurrentEpochId();

        uint256 frameFirstEpochId = oracle.getFrameFirstEpochId(epochId);
        if (frameFirstEpochId > 0) {
            vm.startPrank(oracleOne);
            oracle.reportBeacon(frameFirstEpochId, balanceSum, validatorCount);
            vm.stopPrank();

            uint256 oneYearAway = uint256(GENESIS_TIME) + uint256(timeFromGenesis) + 364.9 days;
            vm.warp(oneYearAway);
            uint256 futureEpochId = oracle.getFrameFirstEpochId(oracle.getCurrentEpochId());
            BeaconReportBounds.BeaconReportBoundsStruct memory bounds = oracle.getBeaconBounds();

            uint256 balanceSumIncrease = ((balanceSum * bounds.annualAprUpperBound) / 10000) + 1;

            if (uint256(balanceSum) + balanceSumIncrease <= type(uint64).max) {
                vm.startPrank(oracleOne);
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "BeaconBalanceIncreaseOutOfBounds(uint256,uint256,uint256,uint256)",
                        1e9 * uint256(balanceSum),
                        (uint256(balanceSum) + uint256(balanceSumIncrease)) * 1e9,
                        (futureEpochId - frameFirstEpochId) * SLOTS_PER_EPOCH * SECONDS_PER_SLOT,
                        UPPER_BOUND
                    )
                );
                oracle.reportBeacon(futureEpochId, balanceSum + uint64(balanceSumIncrease), validatorCount);
                vm.stopPrank();
            }
        }
    }

    function testBreakingLowerBoundLimit(uint64 timeFromGenesis, uint64 balanceSum, uint32 validatorCount) public {
        RiverMock(address(oracleInput)).sudoSetTotalShares(1e9 * uint256(balanceSum));
        RiverMock(address(oracleInput)).sudoSetTotalSupply(1e9 * uint256(balanceSum));

        vm.warp(uint256(GENESIS_TIME) + uint256(timeFromGenesis));
        vm.startPrank(admin);
        oracle.addMember(oracleOne);
        oracle.setQuorum(1);
        vm.stopPrank();

        uint256 epochId = oracle.getCurrentEpochId();

        uint256 frameFirstEpochId = oracle.getFrameFirstEpochId(epochId);
        if (balanceSum > 0) {
            vm.startPrank(oracleOne);
            oracle.reportBeacon(frameFirstEpochId, balanceSum, validatorCount);
            vm.stopPrank();

            uint256 oneEpochAway =
                uint256(GENESIS_TIME) + uint256(timeFromGenesis) + SLOTS_PER_EPOCH * SECONDS_PER_SLOT * EPOCHS_PER_FRAME;
            vm.warp(oneEpochAway);
            uint256 futureEpochId = oracle.getFrameFirstEpochId(oracle.getCurrentEpochId());
            BeaconReportBounds.BeaconReportBoundsStruct memory bounds = oracle.getBeaconBounds();

            uint256 balanceSumDecrease = ((balanceSum * bounds.relativeLowerBound) / 10000) + 1;

            vm.startPrank(oracleOne);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "BeaconBalanceDecreaseOutOfBounds(uint256,uint256,uint256,uint256)",
                    1e9 * uint256(balanceSum),
                    (uint256(balanceSum) - uint256(balanceSumDecrease)) * 1e9,
                    (futureEpochId - frameFirstEpochId) * SLOTS_PER_EPOCH * SECONDS_PER_SLOT,
                    LOWER_BOUND
                )
            );
            oracle.reportBeacon(futureEpochId, balanceSum - uint64(balanceSumDecrease), validatorCount);
            vm.stopPrank();
        }
    }
}
