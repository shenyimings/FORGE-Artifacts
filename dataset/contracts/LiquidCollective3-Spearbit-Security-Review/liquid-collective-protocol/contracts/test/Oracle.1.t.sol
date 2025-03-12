//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./mocks/RiverMock.sol";

import "../src/Oracle.1.sol";
import "../src/interfaces/IRiver.1.sol";

contract OracleV1Tests is Test {
    OracleV1 internal oracle;

    IRiverV1 internal oracleInput;
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

    event SetQuorum(uint256 _newQuorum);
    event AddMember(address indexed member);
    event RemoveMember(address indexed member);
    event SetMember(address indexed oldAddress, address indexed newAddress);
    event SetSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime);
    event SetBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound);
    event SetRiver(address _river);

    function setUp() public {
        oracleInput = IRiverV1(payable(address(new RiverMock())));
        oracle = new OracleV1();
        LibImplementationUnbricker.unbrick(vm, address(oracle));
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(oracleInput));
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
    }

    function testGetAdmin() public view {
        assert(oracle.getAdmin() == admin);
    }

    function testGetRiver() public view {
        assert(oracle.getRiver() == address(oracleInput));
    }

    function testSetQuorum(uint256 newMemberSalt, uint256 anotherMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        address anotherMember = uf._new(anotherMemberSalt);
        vm.startPrank(admin);
        oracle.addMember(newMember, 1);
        oracle.addMember(anotherMember, 2);
        vm.expectEmit(true, true, true, true);
        emit SetQuorum(1);
        oracle.setQuorum(1);
    }

    function testSetQuorumUnauthorized(uint256 newMemberSalt, uint256 anotherMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        address anotherMember = uf._new(anotherMemberSalt);
        vm.startPrank(admin);
        oracle.addMember(newMember, 1);
        oracle.addMember(anotherMember, 2);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        oracle.setQuorum(1);
    }

    function testAddMemberQuorumZero() public {
        address newMember = uf._new(1);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        oracle.addMember(newMember, 0);
    }

    function testRemoveMemberQuorumZero() public {
        address newMemberOne = uf._new(1);
        address newMemberTwo = uf._new(2);
        vm.prank(admin);
        oracle.addMember(newMemberOne, 1);
        vm.prank(admin);
        oracle.addMember(newMemberTwo, 2);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        oracle.removeMember(newMemberOne, 0);
    }

    function testGetMemberStatusRandomAddress(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        assert(oracle.getMemberReportStatus(newMember) == false);
    }

    function testAddMember(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        vm.expectEmit(true, true, true, true);
        emit AddMember(newMember);
        oracle.addMember(newMember, 1);
        assert(oracle.isMember(newMember) == true);
    }

    function testAddMemberQuorumEvent(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        assert(oracle.getQuorum() == 0);
        vm.expectEmit(true, true, true, true);
        emit SetQuorum(1);
        oracle.addMember(newMember, 1);
        assert(oracle.isMember(newMember) == true);
    }

    function testAddMemberUnauthorized(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(newMember);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", newMember));
        oracle.addMember(newMember, 1);
    }

    function testAddMemberExisting(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        oracle.addMember(newMember, 1);
        vm.expectRevert(abi.encodeWithSignature("AddressAlreadyInUse(address)", newMember));
        oracle.addMember(newMember, 1);
    }

    function testRemoveMember(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        oracle.addMember(newMember, 1);
        assert(oracle.isMember(newMember) == true);
        vm.expectEmit(true, true, true, true);
        emit RemoveMember(newMember);
        oracle.removeMember(newMember, 0);
        assert(oracle.isMember(newMember) == false);
    }

    function testRemoveMemberQuorumEvent(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        oracle.addMember(newMember, 1);
        assert(oracle.isMember(newMember) == true);
        vm.expectEmit(true, true, true, true);
        emit SetQuorum(0);
        oracle.removeMember(newMember, 0);
        assert(oracle.isMember(newMember) == false);
    }

    function testEditMember(uint256 newMemberSalt, uint256 newAddressSalt) public {
        address newMember = uf._new(newMemberSalt);
        address newAddress = uf._new(newAddressSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        assert(oracle.isMember(newAddress) == false);
        oracle.addMember(newMember, 1);
        assert(oracle.isMember(newMember) == true);
        assert(oracle.isMember(newAddress) == false);
        vm.stopPrank();
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetMember(newMember, newAddress);
        oracle.setMember(newMember, newAddress);
        vm.stopPrank();
        assert(oracle.isMember(newMember) == false);
        assert(oracle.isMember(newAddress) == true);
    }

    function testEditMemberZero(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        oracle.addMember(newMember, 1);
        vm.stopPrank();
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        oracle.setMember(newMember, address(0));
        vm.stopPrank();
    }

    function testEditMemberAlreadyInUse(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        oracle.addMember(newMember, 1);
        vm.expectRevert(abi.encodeWithSignature("AddressAlreadyInUse(address)", newMember));
        oracle.setMember(newMember, newMember);
        vm.stopPrank();
    }

    function testEditMemberAsMember(uint256 newMemberSalt, uint256 newAddressSalt) public {
        address newMember = uf._new(newMemberSalt);
        address newAddress = uf._new(newAddressSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        assert(oracle.isMember(newAddress) == false);
        oracle.addMember(newMember, 1);
        assert(oracle.isMember(newMember) == true);
        assert(oracle.isMember(newAddress) == false);
        vm.stopPrank();
        vm.startPrank(newMember);
        vm.expectEmit(true, true, true, true);
        emit SetMember(newMember, newAddress);
        oracle.setMember(newMember, newAddress);
        vm.stopPrank();
    }

    function testEditMemberUnauthorized(uint256 newMemberSalt, uint256 newAddressSalt) public {
        address newMember = uf._new(newMemberSalt);
        address newAddress = uf._new(newAddressSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        assert(oracle.isMember(newAddress) == false);
        oracle.addMember(newMember, 1);
        assert(oracle.isMember(newMember) == true);
        assert(oracle.isMember(newAddress) == false);
        vm.stopPrank();
        vm.startPrank(newAddress);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", newAddress));
        oracle.setMember(newMember, newAddress);
        vm.stopPrank();
    }

    function testEditMemberNotFound(uint256 newMemberSalt, uint256 newAddressSalt) public {
        address newMember = uf._new(newMemberSalt);
        address newAddress = uf._new(newAddressSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        assert(oracle.isMember(newAddress) == false);
        oracle.addMember(newMember, 1);
        assert(oracle.isMember(newMember) == true);
        assert(oracle.isMember(newAddress) == false);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        oracle.setMember(newAddress, newAddress);
        vm.stopPrank();
    }

    function testRemoveMemberUnauthorized(uint256 newMemberSalt) public {
        address newMember = uf._new(newMemberSalt);
        vm.startPrank(admin);
        assert(oracle.isMember(newMember) == false);
        oracle.addMember(newMember, 1);
        assert(oracle.isMember(newMember) == true);
        vm.stopPrank();
        vm.startPrank(newMember);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", newMember));
        oracle.removeMember(newMember, 0);
    }

    function testSetQuorumRedundant(uint256 oracleMemberSalt) public {
        address oracleMember = uf._new(oracleMemberSalt);
        vm.startPrank(admin);
        oracle.addMember(oracleMember, 1);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        oracle.setQuorum(1);
        vm.stopPrank();
    }

    function testSetQuorumTooHigh() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        oracle.setQuorum(1);
        vm.stopPrank();
    }

    function _generateEmptyReport(uint256 stoppedValidatorsCountElements)
        internal
        pure
        returns (IOracleManagerV1.ConsensusLayerReport memory clr)
    {
        clr.stoppedValidatorCountPerOperator = new uint32[](stoppedValidatorsCountElements);
    }

    event DebugReceivedReport(IOracleManagerV1.ConsensusLayerReport report);

    function testValidReport(uint256 _salt) external {
        address member = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member), false);

        vm.prank(admin);
        oracle.addMember(member, 1);

        assertEq(oracle.getQuorum(), 1);
        assertEq(oracle.isMember(member), true);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        vm.prank(member);
        vm.expectEmit(true, true, true, true);
        emit DebugReceivedReport(report);
        oracle.reportConsensusLayerData(report);
    }

    function testValidReportMultiVote(uint256 _salt) external {
        address member0 = uf._new(_salt);
        _salt = uint256(keccak256(abi.encode(_salt)));
        address member1 = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member0), false);
        assertEq(oracle.isMember(member1), false);

        vm.prank(admin);
        oracle.addMember(member0, 1);
        vm.prank(admin);
        oracle.addMember(member1, 2);

        assertEq(oracle.getQuorum(), 2);
        assertEq(oracle.isMember(member0), true);
        assertEq(oracle.isMember(member1), true);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        vm.prank(member0);
        oracle.reportConsensusLayerData(report);

        vm.prank(member1);
        vm.expectEmit(true, true, true, true);
        emit DebugReceivedReport(report);
        oracle.reportConsensusLayerData(report);
    }

    function testReportUnauthorized(uint256 _salt) external {
        address member = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member), false);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        vm.prank(member);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", member));
        oracle.reportConsensusLayerData(report);
    }

    function testReportEpochTooOld(uint256 _salt) external {
        address member = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member), false);

        vm.prank(admin);
        oracle.addMember(member, 1);

        assertEq(oracle.getQuorum(), 1);
        assertEq(oracle.isMember(member), true);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        vm.prank(member);
        vm.expectEmit(true, true, true, true);
        emit DebugReceivedReport(report);
        oracle.reportConsensusLayerData(report);

        vm.prank(member);
        vm.expectRevert(abi.encodeWithSignature("EpochTooOld(uint256,uint256)", report.epoch, report.epoch + 1));
        oracle.reportConsensusLayerData(report);
    }

    function testReportEpochInvalidEpoch(uint256 _salt) external {
        address member = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member), false);

        vm.prank(admin);
        oracle.addMember(member, 1);

        assertEq(oracle.getQuorum(), 1);
        assertEq(oracle.isMember(member), true);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        RiverMock(address(oracleInput)).sudoSetInvalidEpoch(report.epoch);

        vm.prank(member);
        vm.expectRevert(abi.encodeWithSignature("InvalidEpoch(uint256)", report.epoch));
        oracle.reportConsensusLayerData(report);
    }

    function testValidReportAlreadyReported(uint256 _salt) external {
        address member0 = uf._new(_salt);
        _salt = uint256(keccak256(abi.encode(_salt)));
        address member1 = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member0), false);
        assertEq(oracle.isMember(member1), false);

        vm.prank(admin);
        oracle.addMember(member0, 1);
        vm.prank(admin);
        oracle.addMember(member1, 2);

        assertEq(oracle.getQuorum(), 2);
        assertEq(oracle.isMember(member0), true);
        assertEq(oracle.isMember(member1), true);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        vm.prank(member0);
        oracle.reportConsensusLayerData(report);

        vm.prank(member0);
        vm.expectRevert(abi.encodeWithSignature("AlreadyReported(uint256,address)", report.epoch, member0));
        oracle.reportConsensusLayerData(report);
    }

    event ClearedReporting();

    function testValidReportClearOnNewReport(uint256 _salt) external {
        address member0 = uf._new(_salt);
        _salt = uint256(keccak256(abi.encode(_salt)));
        address member1 = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member0), false);
        assertEq(oracle.isMember(member1), false);

        vm.prank(admin);
        oracle.addMember(member0, 1);
        vm.prank(admin);
        oracle.addMember(member1, 2);

        assertEq(oracle.getQuorum(), 2);
        assertEq(oracle.isMember(member0), true);
        assertEq(oracle.isMember(member1), true);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        vm.prank(member0);
        oracle.reportConsensusLayerData(report);

        ++report.epoch;

        vm.prank(member0);
        vm.expectEmit(true, true, true, true);
        emit ClearedReporting();
        oracle.reportConsensusLayerData(report);
        ++report.epoch;

        vm.prank(member0);
        vm.expectEmit(true, true, true, true);
        emit ClearedReporting();
        oracle.reportConsensusLayerData(report);

        vm.prank(member1);
        vm.expectEmit(true, true, true, true);
        emit DebugReceivedReport(report);
        oracle.reportConsensusLayerData(report);
    }

    function testValidReportEpochTooOldAfterClear(uint256 _salt) external {
        address member0 = uf._new(_salt);
        _salt = uint256(keccak256(abi.encode(_salt)));
        address member1 = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member0), false);
        assertEq(oracle.isMember(member1), false);

        vm.prank(admin);
        oracle.addMember(member0, 1);
        vm.prank(admin);
        oracle.addMember(member1, 2);

        assertEq(oracle.getQuorum(), 2);
        assertEq(oracle.isMember(member0), true);
        assertEq(oracle.isMember(member1), true);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        vm.prank(member0);
        oracle.reportConsensusLayerData(report);

        ++report.epoch;

        vm.prank(member0);
        vm.expectEmit(true, true, true, true);
        emit ClearedReporting();
        oracle.reportConsensusLayerData(report);

        --report.epoch;

        vm.prank(member1);
        vm.expectRevert(abi.encodeWithSignature("EpochTooOld(uint256,uint256)", report.epoch, report.epoch + 1));
        oracle.reportConsensusLayerData(report);
    }

    function testValidReportClearedAfterNewMemberAdded(uint256 _salt) external {
        address member0 = uf._new(_salt);
        _salt = uint256(keccak256(abi.encode(_salt)));
        address member1 = uf._new(_salt);
        _salt = uint256(keccak256(abi.encode(_salt)));
        address member2 = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member0), false);
        assertEq(oracle.isMember(member1), false);
        assertEq(oracle.isMember(member2), false);

        vm.prank(admin);
        oracle.addMember(member0, 1);
        vm.prank(admin);
        oracle.addMember(member1, 2);

        assertEq(oracle.getQuorum(), 2);
        assertEq(oracle.isMember(member0), true);
        assertEq(oracle.isMember(member1), true);
        assertEq(oracle.isMember(member2), false);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        vm.prank(member0);
        oracle.reportConsensusLayerData(report);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit ClearedReporting();
        oracle.addMember(member2, 3);
    }

    function testValidReportClearedAfterMemberRemoved(uint256 _salt) external {
        address member0 = uf._new(_salt);
        _salt = uint256(keccak256(abi.encode(_salt)));
        address member1 = uf._new(_salt);
        _salt = uint256(keccak256(abi.encode(_salt)));
        address member2 = uf._new(_salt);

        assertEq(oracle.getQuorum(), 0);
        assertEq(oracle.isMember(member0), false);
        assertEq(oracle.isMember(member1), false);
        assertEq(oracle.isMember(member2), false);

        vm.prank(admin);
        oracle.addMember(member0, 1);
        vm.prank(admin);
        oracle.addMember(member1, 2);
        vm.prank(admin);
        oracle.addMember(member2, 3);

        assertEq(oracle.getQuorum(), 3);
        assertEq(oracle.isMember(member0), true);
        assertEq(oracle.isMember(member1), true);
        assertEq(oracle.isMember(member2), true);

        IOracleManagerV1.ConsensusLayerReport memory report = _generateEmptyReport(2);

        vm.prank(member0);
        oracle.reportConsensusLayerData(report);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit ClearedReporting();
        oracle.removeMember(member2, 2);
    }

    function testIsValidEpochForwardsCallToRiver(uint256 _salt) external {
        uint256 epoch = _salt;
        bool result = bool(_salt % 2 == 0);

        bytes memory cdata = abi.encodeWithSelector(IRiverV1(oracleInput).isValidEpoch.selector, epoch);
        bytes memory rdata = abi.encode(result);
        vm.mockCall(address(oracleInput), cdata, rdata);
        vm.expectCall(address(oracleInput), cdata);
        assertEq(oracle.isValidEpoch(_salt), bool(_salt % 2 == 0));
    }

    function testGetTimeForwardsCallToRiver(uint256 _salt) external {
        uint256 result = _salt;

        bytes memory cdata = abi.encodeWithSelector(IRiverV1(oracleInput).getTime.selector);
        bytes memory rdata = abi.encode(result);
        vm.mockCall(address(oracleInput), cdata, rdata);
        vm.expectCall(address(oracleInput), cdata);
        assertEq(oracle.getTime(), result);
    }

    function testGetExpectedEpochIdForwardsCallToRiver(uint256 _salt) external {
        uint256 result = _salt;

        bytes memory cdata = abi.encodeWithSelector(IRiverV1(oracleInput).getExpectedEpochId.selector);
        bytes memory rdata = abi.encode(result);
        vm.mockCall(address(oracleInput), cdata, rdata);
        vm.expectCall(address(oracleInput), cdata);
        assertEq(oracle.getExpectedEpochId(), result);
    }

    function testGetLastCompletedEpochIdForwardsCallToRiver(uint256 _salt) external {
        uint256 result = _salt;

        bytes memory cdata = abi.encodeWithSelector(IRiverV1(oracleInput).getLastCompletedEpochId.selector);
        bytes memory rdata = abi.encode(result);
        vm.mockCall(address(oracleInput), cdata, rdata);
        vm.expectCall(address(oracleInput), cdata);
        assertEq(oracle.getLastCompletedEpochId(), result);
    }

    function testGetCurrentEpochIdForwardsCallToRiver(uint256 _salt) external {
        uint256 result = _salt;

        bytes memory cdata = abi.encodeWithSelector(IRiverV1(oracleInput).getCurrentEpochId.selector);
        bytes memory rdata = abi.encode(result);
        vm.mockCall(address(oracleInput), cdata, rdata);
        vm.expectCall(address(oracleInput), cdata);
        assertEq(oracle.getCurrentEpochId(), result);
    }

    function _next(uint256 _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_salt)));
    }

    function testGetCLSpecForwardsCallToRiver(uint256 _salt) external {
        CLSpec.CLSpecStruct memory cls;
        cls.epochsPerFrame = uint64(_salt);
        _salt = _next(_salt);
        cls.slotsPerEpoch = uint64(_salt);
        _salt = _next(_salt);
        cls.secondsPerSlot = uint64(_salt);
        _salt = _next(_salt);
        cls.genesisTime = uint64(_salt);

        bytes memory cdata = abi.encodeWithSelector(IRiverV1(oracleInput).getCLSpec.selector);
        bytes memory rdata = abi.encode(cls);
        vm.mockCall(address(oracleInput), cdata, rdata);
        vm.expectCall(address(oracleInput), cdata);

        CLSpec.CLSpecStruct memory retrievedCls = oracle.getCLSpec();

        assertEq(retrievedCls.epochsPerFrame, cls.epochsPerFrame);
        assertEq(retrievedCls.slotsPerEpoch, cls.slotsPerEpoch);
        assertEq(retrievedCls.secondsPerSlot, cls.secondsPerSlot);
        assertEq(retrievedCls.genesisTime, cls.genesisTime);
    }

    function testGetCurrentFrameForwardsCallToRiver(uint256 _salt) external {
        uint256 startEpoch = _salt;
        _salt = _next(_salt);
        uint256 startTime = _salt;
        _salt = _next(_salt);
        uint256 endTime = _salt;

        bytes memory cdata = abi.encodeWithSelector(IRiverV1(oracleInput).getCurrentFrame.selector);
        bytes memory rdata = abi.encode(startEpoch, startTime, endTime);
        vm.mockCall(address(oracleInput), cdata, rdata);
        vm.expectCall(address(oracleInput), cdata);
        (uint256 retrievedStartEpoch, uint256 retrievedStartTime, uint256 retrievedEndTime) = oracle.getCurrentFrame();
        assertEq(retrievedStartEpoch, startEpoch);
        assertEq(retrievedStartTime, startTime);
        assertEq(retrievedEndTime, endTime);
    }

    function testGetFrameFirstEpochIdForwardsCallToRiver(uint256 _salt) external {
        uint256 epoch = _salt;
        _salt = _next(_salt);
        uint256 result = _salt;

        bytes memory cdata = abi.encodeWithSelector(IRiverV1(oracleInput).getFrameFirstEpochId.selector);
        bytes memory rdata = abi.encode(result);
        vm.mockCall(address(oracleInput), cdata, rdata);
        vm.expectCall(address(oracleInput), cdata);
        assertEq(oracle.getFrameFirstEpochId(epoch), result);
    }
}
