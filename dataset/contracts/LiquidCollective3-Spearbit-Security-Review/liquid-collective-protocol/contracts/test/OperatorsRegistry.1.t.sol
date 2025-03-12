//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/OperatorsRegistry.1.sol";

contract OperatorsRegistryInitializableV1 is OperatorsRegistryV1 {
    function sudoSetFunded(uint256 _index, uint32 _funded) external {
        OperatorsV2.Operator storage operator = OperatorsV2.get(_index);
        operator.funded = _funded;
    }

    function debugGetNextValidatorsToDepositFromActiveOperators(uint256 _requestedAmount)
        external
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        return _pickNextValidatorsToDepositFromActiveOperators(_requestedAmount);
    }

    function debugGetNextValidatorsToExitFromActiveOperators(uint256 _requestedExitsAmount) external {
        return _pickNextValidatorsToExitFromActiveOperators(_requestedExitsAmount);
    }

    function sudoSetKeys(uint256 _operatorIndex, uint32 _keyCount) external {
        OperatorsV2.setKeys(_operatorIndex, _keyCount);
    }

    function sudoExitRequests(uint256 _operatorIndex, uint32 _requestedExits) external {
        OperatorsV2.get(_operatorIndex).requestedExits = _requestedExits;
    }

    function sudoStoppedValidatorCounts(uint32[] calldata stoppedValidatorCounts) external {
        _setStoppedValidatorCounts(stoppedValidatorCounts);
    }
}

contract OperatorsRegistryV1Tests is Test, BytesGenerator {
    UserFactory internal uf = new UserFactory();

    OperatorsRegistryV1 internal operatorsRegistry;
    address internal admin;
    address internal river;
    string internal firstName = "Operator One";
    string internal secondName = "Operator Two";

    event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
    event RemovedValidatorKey(uint256 indexed index, bytes publicKey);
    event SetRiver(address indexed river);
    event OperatorLimitUnchanged(uint256 indexed operatorIndex, uint256 limit);
    event OperatorEditsAfterSnapshot(
        uint256 indexed index,
        uint256 currentLimit,
        uint256 newLimit,
        uint256 indexed lastEdit,
        uint256 indexed snapshotBlock
    );

    event SetOperatorLimit(uint256 indexed index, uint256 newLimit);
    event AddedValidatorKeys(uint256 indexed index, uint256 amount);
    event UpdatedStoppedValidators(uint32[] stoppedValidatorCounts);

    function setUp() public {
        admin = makeAddr("admin");
        river = makeAddr("river");
        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    function testInitializeTwice() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    function testInternalSetKeys(uint256 _nodeOperatorAddressSalt, bytes32 _name, uint32 _keyCount, uint32 _blockRoll)
        public
    {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        uint256 operatorIndex = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(operatorIndex);
        assert(newOperator.keys == 0);
        assert(newOperator.latestKeysEditBlockNumber == block.number);
        vm.roll(block.number + _blockRoll);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetKeys(0, _keyCount);
        newOperator = operatorsRegistry.getOperator(operatorIndex);
        assert(newOperator.keys == _keyCount);
        assert(newOperator.latestKeysEditBlockNumber == block.number);
    }

    function testAddNodeOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        uint256 operatorIndex = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(operatorIndex);
        assert(newOperator.operator == _nodeOperatorAddress);
    }

    function testAddNodeOperatorInvalidAddress(bytes32 _name) public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        operatorsRegistry.addOperator(string(abi.encodePacked(_name)), address(0));
    }

    function testAddNodeOperatorInvalidName(uint256 _nodeOperatorAddressSalt) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyString()"));
        operatorsRegistry.addOperator("", _nodeOperatorAddress);
    }

    function testAddNodeWhileNotAdminOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
    }

    function testSetOperatorLimitTooHigh(uint256 _nodeOperatorAddressSalt) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_nodeOperatorAddress)), _nodeOperatorAddress);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 1;
        vm.expectRevert(abi.encodeWithSignature("OperatorLimitTooHigh(uint256,uint256,uint256)", 0, 1, 0));
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();
    }

    function testSetOperatorInvariantChecksSkipped(uint256 _nodeOperatorAddressSalt) public {
        vm.roll(1);
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_nodeOperatorAddress)), _nodeOperatorAddress);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 1;
        vm.expectEmit(true, true, true, true);
        emit OperatorEditsAfterSnapshot(0, 0, 1, 1, 0);
        operatorsRegistry.setOperatorLimits(indexes, limits, 0);
        vm.stopPrank();
    }

    function testSetOperatorLimitTooLow(uint256 _nodeOperatorAddressSalt) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_nodeOperatorAddress)), _nodeOperatorAddress);
        vm.stopPrank();
        vm.startPrank(_nodeOperatorAddress);
        operatorsRegistry.addValidators(0, 1, genBytes(48 + 96));
        vm.stopPrank();
        vm.startPrank(admin);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 1;
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(0, 1);
        limits[0] = 0;
        vm.expectRevert(abi.encodeWithSignature("OperatorLimitTooLow(uint256,uint256,uint256)", 0, 0, 1));
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();
    }

    function testSetOperatorAddressesAsAdmin(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
        public
    {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        operatorsRegistry.setOperatorAddress(index, _secondAddress);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _secondAddress);
        vm.stopPrank();
    }

    function testSetOperatorAddressAsOperator(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
        public
    {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.setOperatorAddress(index, _secondAddress);
        vm.stopPrank();
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _secondAddress);
    }

    function testSetOperatorAddressZeroAddr(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        vm.stopPrank();
        vm.startPrank(_firstAddress);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        operatorsRegistry.setOperatorAddress(index, address(0));
        vm.stopPrank();
    }

    function testSetOperatorAddressAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
        public
    {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorAddress(index, _secondAddress);
        vm.stopPrank();
    }

    function testSetOperatorNameAsAdmin(bytes32 _name, uint256 _addressSalt) public {
        address _address = uf._new(_addressSalt);
        bytes32 _nextName = keccak256(abi.encodePacked(_name));
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _address);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_name)))));
        operatorsRegistry.setOperatorName(index, string(abi.encodePacked(_nextName)));
        newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_nextName)))));
        vm.stopPrank();
    }

    function testSetOperatorNameAsOperator(bytes32 _name, uint256 _addressSalt) public {
        address _address = uf._new(_addressSalt);
        bytes32 _nextName = keccak256(abi.encodePacked(_name));
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _address);
        vm.stopPrank();
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_name)))));
        vm.startPrank(_address);
        operatorsRegistry.setOperatorName(index, string(abi.encodePacked(_nextName)));
        vm.stopPrank();
        newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_nextName)))));
    }

    function testSetOperatorNameEmptyString(bytes32 _name, uint256 _addressSalt) public {
        address _address = uf._new(_addressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _address);
        vm.stopPrank();
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_name)))));
        vm.startPrank(_address);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyString()"));
        operatorsRegistry.setOperatorName(index, "");
        vm.stopPrank();
    }

    function testSetOperatorNameAsUnauthorized(bytes32 _name, uint256 _addressSalt) public {
        address _address = uf._new(_addressSalt);
        bytes32 _nextName = keccak256(abi.encodePacked(_name));
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _address);
        vm.stopPrank();
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_name)))));
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorName(index, string(abi.encodePacked(_nextName)));
        vm.stopPrank();
    }

    function testSetOperatorStatusAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == true);
        operatorsRegistry.setOperatorStatus(index, false);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == false);
        operatorsRegistry.setOperatorStatus(index, true);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == true);
    }

    function testSetOperatorStatusAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == true);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorStatus(index, false);
    }

    function testSetOperatorLimitCountAsAdmin(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        _limit = _limit % 11; // 10 is max
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = _limit;
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == _limit);
        operatorLimits[0] = 0;
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
    }

    function testSetOperatorLimitCountNoOp(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        _limit = _limit % 11; // 10 is max
        vm.assume(_limit > 0);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = _limit;
        vm.record();
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        (, bytes32[] memory writes) = vm.accesses(address(operatorsRegistry));
        assert(writes.length == 1);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == _limit);
        vm.expectEmit(true, true, true, true);
        emit OperatorLimitUnchanged(0, _limit);
        vm.record();
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        (, writes) = vm.accesses(address(operatorsRegistry));
        assert(writes.length == 0);
    }

    function testSetOperatorLimitCountSnapshotTooLow(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        _limit = 1 + _limit % 10; // 10 is max, 1 is min
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        uint256 bn = 1_000_000;
        vm.roll(bn);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = _limit;
        vm.expectEmit(true, true, true, true);
        emit OperatorEditsAfterSnapshot(index, 0, _limit, bn, bn - 1);
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, bn - 1);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
    }

    function testSetOperatorLimitDecreaseSkipsSnapshotCheck(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        uint256 bn = 1_000_000;
        vm.roll(bn);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = 10;
        vm.expectEmit(true, true, true, true);
        emit SetOperatorLimit(index, 10);
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, bn);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 10);
        operatorLimits[0] = 5;
        vm.expectEmit(true, true, true, true);
        emit SetOperatorLimit(index, 5);
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, bn - 1);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 5);
    }

    function testSetOperatorLimitCountAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        vm.stopPrank();
        vm.startPrank(address(this));
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = _limit;
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
    }

    function testSetOperatorLimitUnorderedOperators(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint256 _secondAddressSalt
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index0 = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        uint256 index1 = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _secondAddress);
        uint256[] memory operatorIndexes = new uint256[](2);
        operatorIndexes[0] = index1;
        operatorIndexes[1] = index0;
        uint32[] memory operatorLimits = new uint32[](2);
        operatorLimits[0] = 0;
        operatorLimits[1] = 0;
        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        vm.stopPrank();
    }

    function testSetOperatorLimitDuplicateOperators(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        uint256[] memory operatorIndexes = new uint256[](2);
        operatorIndexes[0] = index;
        operatorIndexes[1] = index;
        uint32[] memory operatorLimits = new uint32[](2);
        operatorLimits[0] = 0;
        operatorLimits[1] = 0;
        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        vm.stopPrank();
    }

    function testAddValidatorsAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        vm.expectEmit(true, true, true, true);
        emit AddedValidatorKeys(index, tenKeys);
        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        (,, bool funded) = operatorsRegistry.getValidator(index, 0);
        assert(funded == false);
        (,, funded) = operatorsRegistry.getValidator(index, 1);
        assert(funded == false);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(index, 1);

        (,, funded) = operatorsRegistry.getValidator(index, 0);
        assert(funded == true);
        (,, funded) = operatorsRegistry.getValidator(index, 1);
        assert(funded == false);
    }

    function testGetKeysAsRiver(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);
        vm.stopPrank();

        vm.startPrank(admin);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operatorIndexes, limits, block.number);
        vm.stopPrank();

        vm.startPrank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) = operatorsRegistry.pickNextValidatorsToDeposit(10);
        vm.stopPrank();
        assert(publicKeys.length == 10);
        assert(keccak256(publicKeys[0]) == keccak256(LibBytes.slice(tenKeys, 0, 48)));
        assert(keccak256(signatures[0]) == keccak256(LibBytes.slice(tenKeys, 48, 96)));
    }

    function testGetKeysAsRiverLimitTest(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);
        vm.stopPrank();

        vm.startPrank(admin);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 5;
        operatorsRegistry.setOperatorLimits(operatorIndexes, limits, block.number);
        vm.stopPrank();

        vm.startPrank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) = operatorsRegistry.pickNextValidatorsToDeposit(10);
        vm.stopPrank();
        assert(publicKeys.length == 5);
        assert(keccak256(publicKeys[0]) == keccak256(LibBytes.slice(tenKeys, 0, 48)));
        assert(keccak256(signatures[0]) == keccak256(LibBytes.slice(tenKeys, 48, 96)));
    }

    function testGetKeysDistribution(uint256 _operatorOneSalt, uint256 _operatorTwoSalt, uint256 _operatorThreeSalt)
        external
    {
        address _operatorOne = uf._new(_operatorOneSalt);
        address _operatorTwo = uf._new(_operatorTwoSalt);
        address _operatorThree = uf._new(_operatorThreeSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorOne)), _operatorOne);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorTwo)), _operatorTwo);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorThree)), _operatorThree);
        vm.stopPrank();

        assert(operatorsRegistry.getOperatorCount() == 3);

        {
            bytes memory fiftyKeys = genBytes(50 * (48 + 96));

            vm.prank(_operatorOne);
            operatorsRegistry.addValidators(0, 50, fiftyKeys);
        }
        {
            bytes memory fiftyKeys = genBytes(50 * (48 + 96));

            vm.prank(_operatorTwo);
            operatorsRegistry.addValidators(1, 50, fiftyKeys);
        }
        {
            bytes memory fiftyKeys = genBytes(50 * (48 + 96));

            vm.prank(_operatorThree);
            operatorsRegistry.addValidators(2, 50, fiftyKeys);
        }

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) = operatorsRegistry.pickNextValidatorsToDeposit(6);

        assert(publicKeys.length == 6);
        assert(signatures.length == 6);

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 5);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 1);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 0);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }
        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDeposit(6);

        assert(publicKeys.length == 6);
        assert(signatures.length == 6);

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 5);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 2);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 5);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDeposit(64);

        assert(publicKeys.length == 64);
        assert(signatures.length == 64);

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 25);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 26);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 25);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDeposit(74);

        assert(publicKeys.length == 74);
        assert(signatures.length == 74);

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 50);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 50);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 50);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }
    }

    function testGetAllActiveOperators(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        OperatorsV2.Operator[] memory operators = operatorsRegistry.listActiveOperators();

        assert(operators.length == 1);
        assert(keccak256(bytes(operators[0].name)) == keccak256(abi.encodePacked(_name)));
        assert(operators[0].operator == _firstAddress);
    }

    function testGetAllActiveOperatorsWithInactiveOnes(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        operatorsRegistry.setOperatorStatus(index, false);

        OperatorsV2.Operator[] memory operators = operatorsRegistry.listActiveOperators();

        assert(operators.length == 0);
    }

    function testGetKeysAsRiverNoKeys() public {
        vm.startPrank(river);
        (bytes[] memory publicKeys,) = operatorsRegistry.pickNextValidatorsToDeposit(10);
        vm.stopPrank();
        assert(publicKeys.length == 0);
    }

    function testGetKeysAsUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.pickNextValidatorsToDeposit(10);
    }

    function testRequestExitAsUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.pickNextValidatorsToExit(10);
    }

    function testAddValidatorsAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.expectEmit(true, true, true, true);
        emit AddedValidatorKeys(index, tenKeys);
        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);
    }

    function testAddValidatorsAsAdminUnknownOperator(uint256 _index) public {
        vm.startPrank(admin);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", _index));
        operatorsRegistry.addValidators(_index, 10, tenKeys);
    }

    function testAddValidatorsAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.addValidators(index, 10, tenKeys);
    }

    function testAddValidatorsInvalidKeySize(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 9);

        vm.expectRevert(abi.encodeWithSignature("InvalidKeysLength()"));
        operatorsRegistry.addValidators(index, 10, tenKeys);
    }

    function testAddValidatorsInvalidCount(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        vm.expectRevert(abi.encodeWithSignature("InvalidKeyCount()"));
        operatorsRegistry.addValidators(index, 0, "");
    }

    function testRemoveValidatorsAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        vm.expectEmit(true, true, true, true);
        emit RemovedValidatorKey(index, LibBytes.slice(tenKeys, 0, 48));
        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 0);
        assert(operator.limit == 0);

        operatorsRegistry.addValidators(index, 10, tenKeys);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);
    }

    function testRemoveHalfValidatorsEvenCaseAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);
        vm.stopPrank();
        vm.startPrank(admin);
        uint256[] memory operators = new uint256[](1);
        uint32[] memory limits = new uint32[](1);
        operators[0] = index;
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();
        vm.startPrank(_firstAddress);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](5);

        indexes[0] = 8;
        indexes[1] = 6;
        indexes[2] = 4;
        indexes[3] = 2;
        indexes[4] = 0;

        vm.expectEmit(true, true, true, true);
        emit RemovedValidatorKey(index, LibBytes.slice(tenKeys, 0, 48));
        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 5);
        assert(operator.limit == 5);

        operatorsRegistry.addValidators(index, 10, tenKeys);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 15);
    }

    function testRemoveHalfValidatorsConservativeCaseAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);
        vm.stopPrank();
        vm.startPrank(admin);
        uint256[] memory operators = new uint256[](1);
        uint32[] memory limits = new uint32[](1);
        operators[0] = index;
        limits[0] = 8;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();
        vm.startPrank(_firstAddress);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](5);

        indexes[0] = 8;
        indexes[1] = 6;
        indexes[2] = 4;
        indexes[3] = 2;
        indexes[4] = 0;

        vm.expectEmit(true, true, true, true);
        emit RemovedValidatorKey(index, LibBytes.slice(tenKeys, 0, 48));
        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 5);
        assert(operator.limit == 0);

        operatorsRegistry.addValidators(index, 10, tenKeys);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 15);
    }

    function testRemoveValidatorsAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 0);

        operatorsRegistry.addValidators(index, 10, tenKeys);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);
    }

    function testRemoveValidatorsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        vm.stopPrank();
        vm.startPrank(address(this));

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.removeValidators(index, indexes);
    }

    function testRemoveValidatorsAndRetrieveAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](1);

        indexes[0] = 0;

        (bytes memory pk, bytes memory s,) = operatorsRegistry.getValidator(index, 9);

        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 9);
        (bytes memory pkAfter, bytes memory sAfter,) = operatorsRegistry.getValidator(index, 0);

        assert(keccak256(pkAfter) == keccak256(pk));
        assert(keccak256(sAfter) == keccak256(s));
    }

    function testRemoveValidatorsFundedKeyRemovalAttempt(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(index, 10);

        vm.expectRevert(abi.encodeWithSignature("InvalidFundedKeyDeletionAttempt()"));
        operatorsRegistry.removeValidators(index, indexes);
    }

    function testRemoveValidatorsKeyOutOfBounds(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 10;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        vm.expectRevert(abi.encodeWithSignature("InvalidIndexOutOfBounds()"));
        operatorsRegistry.removeValidators(index, indexes);
    }

    function testRemoveValidatorsUnsortedIndexes(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 1;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        vm.expectRevert(abi.encodeWithSignature("InvalidUnsortedIndexes()"));
        operatorsRegistry.removeValidators(index, indexes);
    }

    function testGetOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.active == true);
    }

    function testGetOperatorCount(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        assert(operatorsRegistry.getOperatorCount() == 0);
        operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        assert(operatorsRegistry.getOperatorCount() == 1);
    }

    function testGetStoppedValidatorCounts() public {
        assertEq(operatorsRegistry.getOperatorStoppedValidatorCount(0), 0);
        assertEq(operatorsRegistry.getTotalStoppedValidatorCount(), 0);
    }

    function testReportStoppedValidatorCounts(uint32 totalCount, uint8 len) public {
        vm.assume(len > 0 && len < type(uint8).max);
        totalCount = uint32(bound(totalCount, len, type(uint32).max));

        uint32[] memory stoppedValidatorCounts = new uint32[](len + 1);
        stoppedValidatorCounts[0] = totalCount;

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            vm.prank(admin);
            operatorsRegistry.addOperator(string(abi.encodePacked(idx)), address(123));
            stoppedValidatorCounts[idx] = (totalCount / len) + (idx - 1 < totalCount % len ? 1 : 0);
        }

        vm.prank(river);
        vm.expectEmit(true, true, true, true);
        emit UpdatedStoppedValidators(stoppedValidatorCounts);
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidatorCounts);

        assertEq(operatorsRegistry.getTotalStoppedValidatorCount(), totalCount);
        uint32[] memory rawStoppedValidators = operatorsRegistry.getStoppedValidatorCountPerOperator();

        assertEq(rawStoppedValidators.length, stoppedValidatorCounts.length - 1);

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            assertEq(stoppedValidatorCounts[idx], operatorsRegistry.getOperatorStoppedValidatorCount(idx - 1));
            assertEq(stoppedValidatorCounts[idx], rawStoppedValidators[idx - 1]);
        }
    }

    function testReportStoppedValidatorCountsUnauthorized(uint256 _salt, uint32 totalCount, uint8 len) public {
        address random = uf._new(_salt);
        vm.assume(len > 0 && len < type(uint8).max);
        totalCount = uint32(bound(totalCount, len, type(uint32).max));

        uint32[] memory stoppedValidatorCounts = new uint32[](len + 1);
        stoppedValidatorCounts[0] = totalCount;

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            vm.prank(admin);
            operatorsRegistry.addOperator(string(abi.encodePacked(idx)), address(123));
            stoppedValidatorCounts[idx] = (totalCount / len) + (idx - 1 < totalCount % len ? 1 : 0);
        }

        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", random));
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidatorCounts);
    }

    function testReportStoppedValidatorCountsEmptyArray() public {
        uint32[] memory stoppedValidators = new uint32[](0);
        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyStoppedValidatorCountsArray()"));
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidators);
    }

    function testReportStoppedValidatorCountsMoreElementsThanOperators() public {
        uint32[] memory stoppedValidators = new uint32[](2);
        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("StoppedValidatorCountsTooHigh()"));
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidators);
    }

    function testReportStoppedValidatorCountsInvalidSum(uint32 totalCount, uint8 len) public {
        vm.assume(len > 0 && len < type(uint8).max);
        totalCount = uint32(bound(totalCount, len, type(uint32).max));

        uint32[] memory stoppedValidators = new uint32[](len + 1);
        stoppedValidators[0] = totalCount;

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            vm.prank(admin);
            operatorsRegistry.addOperator(string(abi.encodePacked(idx)), address(123));
            stoppedValidators[idx] = (totalCount / len) + (idx - 1 < totalCount % len ? 1 : 0);
        }

        stoppedValidators[0] -= 1;

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InvalidStoppedValidatorCountsSum()"));
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidators);
    }
}

contract OperatorsRegistryV1TestDistribution is Test {
    UserFactory internal uf = new UserFactory();

    OperatorsRegistryV1 internal operatorsRegistry;
    address internal admin;
    address internal river;
    string internal firstName = "Operator One";
    string internal secondName = "Operator Two";

    address internal operatorOne;
    address internal operatorTwo;
    address internal operatorThree;
    address internal operatorFour;
    address internal operatorFive;

    event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
    event RemovedValidatorKey(uint256 indexed index, bytes publicKey);
    event RequestedValidatorExits(uint256 indexed index, uint256 count);
    event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred);

    bytes32 salt = bytes32(0);

    function genBytes(uint256 len) internal returns (bytes memory) {
        bytes memory res = "";
        while (res.length < len) {
            salt = keccak256(abi.encodePacked(salt));
            if (len - res.length >= 32) {
                res = bytes.concat(res, abi.encode(salt));
            } else {
                res = bytes.concat(res, LibBytes.slice(abi.encode(salt), 0, len - res.length));
            }
        }
        return res;
    }

    function setUp() public {
        admin = makeAddr("admin");
        river = makeAddr("river");

        operatorOne = makeAddr("operatorOne");
        operatorTwo = makeAddr("operatorTwo");
        operatorThree = makeAddr("operatorThree");
        operatorFour = makeAddr("operatorFour");
        operatorFive = makeAddr("operatorFive");

        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);

        vm.startPrank(admin);
        operatorsRegistry.addOperator("operatorOne", operatorOne);
        operatorsRegistry.addOperator("operatorTwo", operatorTwo);
        operatorsRegistry.addOperator("operatorThree", operatorThree);
        operatorsRegistry.addOperator("operatorFour", operatorFour);
        operatorsRegistry.addOperator("operatorFive", operatorFive);
        vm.stopPrank();
    }

    function _bytesToPublicKeysArray(bytes memory raw, uint256 start, uint256 end)
        internal
        pure
        returns (bytes[] memory res)
    {
        if ((end - start) % (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH) != 0) {
            revert();
        }
        uint256 count = (end - start) / (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH);
        res = new bytes[](count);
        for (uint256 idx = 0; idx < count; ++idx) {
            res[idx] = LibBytes.slice(
                raw,
                start + (idx * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)),
                ValidatorKeys.PUBLIC_KEY_LENGTH
            );
        }
    }

    function testRegularDepositDistribution() external {
        bytes[] memory rawKeys = new bytes[](5);

        rawKeys[0] = genBytes((48 + 96) * 50);
        rawKeys[1] = genBytes((48 + 96) * 50);
        rawKeys[2] = genBytes((48 + 96) * 50);
        rawKeys[3] = genBytes((48 + 96) * 50);
        rawKeys[4] = genBytes((48 + 96) * 50);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, rawKeys[0]);
        operatorsRegistry.addValidators(1, 50, rawKeys[1]);
        operatorsRegistry.addValidators(2, 50, rawKeys[2]);
        operatorsRegistry.addValidators(3, 50, rawKeys[3]);
        operatorsRegistry.addValidators(4, 50, rawKeys[4]);
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        {
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                0,
                _bytesToPublicKeysArray(
                    rawKeys[0], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                1,
                _bytesToPublicKeysArray(
                    rawKeys[1], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                2,
                _bytesToPublicKeysArray(
                    rawKeys[2], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                3,
                _bytesToPublicKeysArray(
                    rawKeys[3], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                4,
                _bytesToPublicKeysArray(
                    rawKeys[4], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                address(operatorsRegistry)
            ).debugGetNextValidatorsToDepositFromActiveOperators(50);

            assert(publicKeys.length == 50);
            assert(signatures.length == 50);

            assert(operatorsRegistry.getOperator(0).funded == 10);
            assert(operatorsRegistry.getOperator(1).funded == 10);
            assert(operatorsRegistry.getOperator(2).funded == 10);
            assert(operatorsRegistry.getOperator(3).funded == 10);
            assert(operatorsRegistry.getOperator(4).funded == 10);
        }
        {
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                0,
                _bytesToPublicKeysArray(
                    rawKeys[0],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                1,
                _bytesToPublicKeysArray(
                    rawKeys[1],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                2,
                _bytesToPublicKeysArray(
                    rawKeys[2],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                3,
                _bytesToPublicKeysArray(
                    rawKeys[3],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                4,
                _bytesToPublicKeysArray(
                    rawKeys[4],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                address(operatorsRegistry)
            ).debugGetNextValidatorsToDepositFromActiveOperators(200);

            assert(publicKeys.length == 200);
            assert(signatures.length == 200);

            assert(operatorsRegistry.getOperator(0).funded == 50);
            assert(operatorsRegistry.getOperator(1).funded == 50);
            assert(operatorsRegistry.getOperator(2).funded == 50);
            assert(operatorsRegistry.getOperator(3).funded == 50);
            assert(operatorsRegistry.getOperator(4).funded == 50);
        }
    }

    function testInactiveDepositDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));

        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.startPrank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        operatorsRegistry.setOperatorStatus(1, false);
        operatorsRegistry.setOperatorStatus(3, false);
        vm.stopPrank();

        {
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                address(operatorsRegistry)
            ).debugGetNextValidatorsToDepositFromActiveOperators(250);

            assert(publicKeys.length == 150);
            assert(signatures.length == 150);

            assert(operatorsRegistry.getOperator(0).funded == 50);
            assert(operatorsRegistry.getOperator(1).funded == 0);
            assert(operatorsRegistry.getOperator(2).funded == 50);
            assert(operatorsRegistry.getOperator(3).funded == 0);
            assert(operatorsRegistry.getOperator(4).funded == 50);
        }
    }

    function testStoppedDepositDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));

        vm.stopPrank();

        uint32[] memory limits = new uint32[](3);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;

        uint256[] memory operators = new uint256[](3);
        operators[0] = 0;
        operators[1] = 2;
        operators[2] = 4;

        vm.startPrank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            75
        );
        assert(operatorsRegistry.getOperator(0).funded == 25);
        assert(operatorsRegistry.getOperator(1).funded == 0);
        assert(operatorsRegistry.getOperator(2).funded == 25);
        assert(operatorsRegistry.getOperator(3).funded == 0);
        assert(operatorsRegistry.getOperator(4).funded == 25);

        vm.startPrank(admin);

        uint32[] memory stoppedValidatorCounts = new uint32[](6);
        stoppedValidatorCounts[0] = 75;
        stoppedValidatorCounts[1] = 25;
        stoppedValidatorCounts[3] = 25;
        stoppedValidatorCounts[5] = 25;

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedValidatorCounts);

        limits = new uint32[](2);
        limits[0] = 50;
        limits[1] = 50;

        operators = new uint256[](2);
        operators[0] = 1;
        operators[1] = 3;

        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        vm.stopPrank();

        {
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                address(operatorsRegistry)
            ).debugGetNextValidatorsToDepositFromActiveOperators(50);

            assert(publicKeys.length == 50);
            assert(signatures.length == 50);

            assert(operatorsRegistry.getOperator(0).funded == 35);
            assert(operatorsRegistry.getOperator(1).funded == 10);
            assert(operatorsRegistry.getOperator(2).funded == 35);
            assert(operatorsRegistry.getOperator(3).funded == 10);
            assert(operatorsRegistry.getOperator(4).funded == 35);
        }
    }

    function testDepositDistributionWithOperatorsWithPositiveStoppedDelta() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            50
        );
        assert(operatorsRegistry.getOperator(0).funded == 10);
        assert(operatorsRegistry.getOperator(1).funded == 10);
        assert(operatorsRegistry.getOperator(2).funded == 10);
        assert(operatorsRegistry.getOperator(3).funded == 10);
        assert(operatorsRegistry.getOperator(4).funded == 10);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 10);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(50);

        assert(operatorsRegistry.getOperator(0).requestedExits == 10);
        assert(operatorsRegistry.getOperator(1).requestedExits == 10);
        assert(operatorsRegistry.getOperator(2).requestedExits == 10);
        assert(operatorsRegistry.getOperator(3).requestedExits == 10);
        assert(operatorsRegistry.getOperator(4).requestedExits == 10);

        uint32[] memory stoppedValidatorCounts = new uint32[](6);
        stoppedValidatorCounts[0] = 47;
        stoppedValidatorCounts[1] = 9;
        stoppedValidatorCounts[2] = 10;
        stoppedValidatorCounts[3] = 9;
        stoppedValidatorCounts[4] = 10;
        stoppedValidatorCounts[5] = 9;

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedValidatorCounts);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            50
        );
        assert(operatorsRegistry.getOperator(0).funded == 10);
        assert(operatorsRegistry.getOperator(1).funded == 35);
        assert(operatorsRegistry.getOperator(2).funded == 10);
        assert(operatorsRegistry.getOperator(3).funded == 35);
        assert(operatorsRegistry.getOperator(4).funded == 10);
    }

    event SetTotalRequestedValidatorExits(uint256 previousTotalRequestedExits, uint256 newTotalRequestedExits);

    function testRegularExitDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            250
        );
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 50);
        vm.expectEmit(true, true, true, true);
        emit SetTotalRequestedValidatorExits(0, 250);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(
            250
        );

        assert(operatorsRegistry.getOperator(0).requestedExits == 50);
        assert(operatorsRegistry.getOperator(1).requestedExits == 50);
        assert(operatorsRegistry.getOperator(2).requestedExits == 50);
        assert(operatorsRegistry.getOperator(3).requestedExits == 50);
        assert(operatorsRegistry.getOperator(4).requestedExits == 50);
        assert(operatorsRegistry.getTotalRequestedValidatorExitsCount() == 250);
    }

    function testOneExitDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            250
        );
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 1);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(1);

        assert(operatorsRegistry.getOperator(0).requestedExits == 1);
        assert(operatorsRegistry.getOperator(1).requestedExits == 0);
        assert(operatorsRegistry.getOperator(2).requestedExits == 0);
        assert(operatorsRegistry.getOperator(3).requestedExits == 0);
        assert(operatorsRegistry.getOperator(4).requestedExits == 0);
        assert(operatorsRegistry.getTotalRequestedValidatorExitsCount() == 1);
    }

    event UpdatedRequestedValidatorExitsUponStopped(
        uint256 indexed index, uint32 oldRequestedExits, uint32 newRequestedExits
    );

    function testExitDistributionWithCatchupToStopped() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            250
        );
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 10);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(50);

        assert(operatorsRegistry.getOperator(0).requestedExits == 10);
        assert(operatorsRegistry.getOperator(1).requestedExits == 10);
        assert(operatorsRegistry.getOperator(2).requestedExits == 10);
        assert(operatorsRegistry.getOperator(3).requestedExits == 10);
        assert(operatorsRegistry.getOperator(4).requestedExits == 10);

        uint32[] memory stoppedValidatorCounts = new uint32[](6);
        stoppedValidatorCounts[0] = 65;
        stoppedValidatorCounts[1] = 11;
        stoppedValidatorCounts[2] = 12;
        stoppedValidatorCounts[3] = 13;
        stoppedValidatorCounts[4] = 14;
        stoppedValidatorCounts[5] = 15;

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedValidatorCounts);

        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedValidatorExitsUponStopped(0, 10, 11);
        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedValidatorExitsUponStopped(1, 10, 12);
        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedValidatorExitsUponStopped(2, 10, 13);
        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedValidatorExitsUponStopped(3, 10, 14);
        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedValidatorExitsUponStopped(4, 10, 15);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 23);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 23);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 23);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 23);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 23);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(50);

        assert(operatorsRegistry.getOperator(0).requestedExits == 23);
        assert(operatorsRegistry.getOperator(1).requestedExits == 23);
        assert(operatorsRegistry.getOperator(2).requestedExits == 23);
        assert(operatorsRegistry.getOperator(3).requestedExits == 23);
        assert(operatorsRegistry.getOperator(4).requestedExits == 23);

        assert(operatorsRegistry.getTotalRequestedValidatorExitsCount() == 115);
    }

    function testMoreThanMaxExitDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            250
        );
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 50);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(
            500
        );

        assert(operatorsRegistry.getOperator(0).requestedExits == 50);
        assert(operatorsRegistry.getOperator(1).requestedExits == 50);
        assert(operatorsRegistry.getOperator(2).requestedExits == 50);
        assert(operatorsRegistry.getOperator(3).requestedExits == 50);
        assert(operatorsRegistry.getOperator(4).requestedExits == 50);

        assert(operatorsRegistry.getTotalRequestedValidatorExitsCount() == 250);
    }

    function testMoreThanMaxExitDistributionOnUnevenSetup() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 40, genBytes((48 + 96) * 40));
        operatorsRegistry.addValidators(2, 30, genBytes((48 + 96) * 30));
        operatorsRegistry.addValidators(3, 20, genBytes((48 + 96) * 20));
        operatorsRegistry.addValidators(4, 10, genBytes((48 + 96) * 10));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 40;
        limits[2] = 30;
        limits[3] = 20;
        limits[4] = 10;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            250
        );
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 40);
        assert(operatorsRegistry.getOperator(2).funded == 30);
        assert(operatorsRegistry.getOperator(3).funded == 20);
        assert(operatorsRegistry.getOperator(4).funded == 10);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 40);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 30);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 20);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 10);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(
            500
        );

        assert(operatorsRegistry.getOperator(0).requestedExits == 50);
        assert(operatorsRegistry.getOperator(1).requestedExits == 40);
        assert(operatorsRegistry.getOperator(2).requestedExits == 30);
        assert(operatorsRegistry.getOperator(3).requestedExits == 20);
        assert(operatorsRegistry.getOperator(4).requestedExits == 10);

        assert(operatorsRegistry.getTotalRequestedValidatorExitsCount() == 150);
    }

    function testUnevenExitDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            250
        );
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 3);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 3);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 3);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 3);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 2);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(14);

        assert(operatorsRegistry.getOperator(0).requestedExits == 3);
        assert(operatorsRegistry.getOperator(1).requestedExits == 3);
        assert(operatorsRegistry.getOperator(2).requestedExits == 3);
        assert(operatorsRegistry.getOperator(3).requestedExits == 3);
        assert(operatorsRegistry.getOperator(4).requestedExits == 2);

        assert(operatorsRegistry.getTotalRequestedValidatorExitsCount() == 14);
    }

    function testExitDistributionUnevenFunded() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 40, genBytes((48 + 96) * 40));
        operatorsRegistry.addValidators(2, 30, genBytes((48 + 96) * 30));
        operatorsRegistry.addValidators(3, 30, genBytes((48 + 96) * 30));
        operatorsRegistry.addValidators(4, 10, genBytes((48 + 96) * 10));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 40;
        limits[2] = 30;
        limits[3] = 30;
        limits[4] = 10;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToDepositFromActiveOperators(
            160
        );
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 40);
        assert(operatorsRegistry.getOperator(2).funded == 30);
        assert(operatorsRegistry.getOperator(3).funded == 30);
        assert(operatorsRegistry.getOperator(4).funded == 10);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 20);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 10);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(30);

        assert(operatorsRegistry.getOperator(0).requestedExits == 20);
        assert(operatorsRegistry.getOperator(1).requestedExits == 10);
        assert(operatorsRegistry.getOperator(2).requestedExits == 0);
        assert(operatorsRegistry.getOperator(3).requestedExits == 0);
        assert(operatorsRegistry.getOperator(4).requestedExits == 0);

        assert(operatorsRegistry.getTotalRequestedValidatorExitsCount() == 30);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 30);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 20);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 10);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(40);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 40);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 30);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 20);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 20);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(40);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 40);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 30);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 30);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 10);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsToExitFromActiveOperators(50);
    }
}
