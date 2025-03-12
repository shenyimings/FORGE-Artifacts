//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../Vm.sol";
import "../../src/components/OracleManager.1.sol";
import "../../src/libraries/Errors.sol";
import "../../src/state/shared/AdministratorAddress.sol";
import "../utils/UserFactory.sol";

contract OracleManagerV1ExposeInitializer is OracleManagerV1 {
    uint256 public lastReceived;
    uint256 public extraAmount;

    function _onEarnings(uint256 amount) internal override {
        lastReceived = amount;
    }

    function _pullELFees() internal view override returns (uint256) {
        return extraAmount;
    }

    function supersedeExtraAmount(uint256 amount) external {
        extraAmount = amount;
    }

    function supersedeBalanceSum(uint256 amount) external {
        BeaconValidatorBalanceSum.set(amount);
    }

    function supersedeAllValidatorCount(uint256 amount) external {
        DepositedValidatorCount.set(amount);
        BeaconValidatorCount.set(amount);
    }

    function supersedeDepositedValidatorCount(uint256 amount) external {
        DepositedValidatorCount.set(amount);
    }

    constructor(address admin) {
        AdministratorAddress.set(admin);
    }
}

contract OracleManagerV1Tests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    UserFactory internal uf = new UserFactory();

    address internal oracle = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);

    OracleManagerV1 internal oracleManager;

    function setUp() public {
        oracleManager = new OracleManagerV1ExposeInitializer(address(this));
        oracleManager.setOracle(oracle);
    }

    function testSetBeaconData(uint64 val2, bytes32 roundId) public {
        vm.startPrank(oracle);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeBalanceSum(32 ether);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeAllValidatorCount(1);
        oracleManager.setBeaconData(1, val2 + 32 ether, roundId);
        assert(OracleManagerV1ExposeInitializer(address(oracleManager)).lastReceived() == val2);
    }

    function testSetBeaconDataWithELFeesPulling(uint64 val2, uint64 val3, bytes32 roundId) public {
        vm.startPrank(oracle);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeBalanceSum(32 ether);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeAllValidatorCount(1);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeExtraAmount(val3);
        oracleManager.setBeaconData(1, val2 + 32 ether, roundId);
        assert(OracleManagerV1ExposeInitializer(address(oracleManager)).lastReceived() == uint256(val2) + uint256(val3));
    }

    function testSetBeaconDataWithValidatorCountDelta(uint64 val2, bytes32 roundId) public {
        vm.startPrank(oracle);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeBalanceSum(32 ether);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeAllValidatorCount(1);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeDepositedValidatorCount(2);
        oracleManager.setBeaconData(2, val2 + 64 ether, roundId);
        assert(OracleManagerV1ExposeInitializer(address(oracleManager)).lastReceived() == val2);
    }

    function testSetBeaconDataUnauthorized(uint256 userSalt, uint64 val1, bytes32 roundId) public {
        address user = uf._new(userSalt);
        vm.startPrank(user);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeAllValidatorCount(1);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        oracleManager.setBeaconData(1, val1 + 32 ether, roundId);
    }

    function testSetBeaconDataInvalidValidatorCount(uint64 val1, bytes32 roundId) public {
        vm.startPrank(oracle);
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeAllValidatorCount(1);
        vm.expectRevert(abi.encodeWithSignature("InvalidValidatorCountReport(uint256,uint256)", 2, 1));
        oracleManager.setBeaconData(2, val1 + 32 ether, roundId);
    }
}
