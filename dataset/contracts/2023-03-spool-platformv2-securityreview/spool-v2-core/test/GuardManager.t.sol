// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/managers/GuardManager.sol";
import {MockGuard} from "./mocks/MockGuard.sol";
import "./utils/GasHelpers.sol";
import "../src/access/SpoolAccessControl.sol";
import "./libraries/Arrays.sol";

contract GuardManagerTest is Test, GasHelpers {
    IGuardManager guardManager;
    MockGuard mockGuard;
    address smartVaultId = address(1);
    address user = address(256);

    function setUp() public {
        SpoolAccessControl accessControl = new SpoolAccessControl();
        accessControl.initialize();
        guardManager = new GuardManager(accessControl);
        mockGuard = new MockGuard();

        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, address(this));

        (GuardDefinition[][] memory guards, RequestType[] memory requestTypes) = _createGuards();
        guardManager.setGuards(smartVaultId, guards, requestTypes);
    }

    function _createGuards() internal view returns (GuardDefinition[][] memory, RequestType[] memory) {
        bytes[] memory emptyBytes = new bytes[](0);
        GuardParamType[] memory paramTypes = new GuardParamType[](1);
        paramTypes[0] = GuardParamType.Executor;

        GuardDefinition memory guard = GuardDefinition(
            address(mockGuard), "isWhitelisted(address)", bytes32(uint256(1)), paramTypes, emptyBytes, "=="
        );

        GuardParamType[] memory paramTypes2 = new GuardParamType[](2);
        paramTypes2[0] = GuardParamType.CustomValue;
        paramTypes2[1] = GuardParamType.Tokens;
        bytes[] memory methodValues2 = new bytes[](1);
        methodValues2[0] = abi.encode(uint256(4));

        GuardDefinition memory guard2 = GuardDefinition(
            address(mockGuard),
            "checkAddressesLength(uint256,address[])",
            bytes32(uint256(1)),
            paramTypes2,
            methodValues2,
            "=="
        );

        GuardDefinition memory guard3 = GuardDefinition(
            address(mockGuard), "isWhitelisted(address)", bytes32(uint256(1)), paramTypes, emptyBytes, "=="
        );

        GuardParamType[] memory paramTypes4 = new GuardParamType[](2);
        paramTypes4[0] = GuardParamType.DynamicCustomValue;
        paramTypes4[1] = GuardParamType.CustomValue;

        bytes[] memory methodValues4 = new bytes[](2);
        uint256[] memory numbersToSum = Arrays.toArray(2, 4, 6);
        methodValues4[0] = abi.encodePacked(numbersToSum);
        methodValues4[1] = abi.encode(uint256(12));

        GuardDefinition memory guard4 = GuardDefinition(
            address(mockGuard),
            "checkArraySum(uint256[],uint256)",
            bytes32(uint256(1)),
            paramTypes4,
            methodValues4,
            "=="
        );

        GuardDefinition[][] memory guards = new GuardDefinition[][](2);
        guards[0] = new GuardDefinition[](3);
        guards[0][0] = guard;
        guards[0][1] = guard2;
        guards[0][2] = guard4;

        guards[1] = new GuardDefinition[](1);
        guards[1][0] = guard3;

        RequestType[] memory requestTypes = new RequestType[](2);
        requestTypes[0] = RequestType.Deposit;
        requestTypes[1] = RequestType.Withdrawal;

        return (guards, requestTypes);
    }

    function test_readGuards() public {
        GuardDefinition[] memory storedGuards = guardManager.readGuards(smartVaultId, RequestType.Deposit);

        assertEq(storedGuards.length, 3);
        assertEq(storedGuards[0].methodParamTypes.length, 1);
        assertEq(uint8(storedGuards[0].methodParamTypes[0]), uint8(GuardParamType.Executor));
    }

    function test_runGuards() public {
        address[] memory tokens = new address[](4);
        tokens[0] = address(10);
        tokens[1] = address(11);
        tokens[2] = address(12);
        tokens[3] = address(13);

        RequestContext memory context = RequestContext(user, user, user, RequestType.Deposit, new uint256[](0), tokens);

        vm.expectRevert(abi.encodeWithSelector(GuardFailed.selector, 0));
        guardManager.runGuards(smartVaultId, context);

        mockGuard.setWhitelist(user, true);

        startMeasuringGas("Test");
        guardManager.runGuards(smartVaultId, context);
        stopMeasuringGas();
    }

    function test_runGuards_resolveOwnerParam() public {
        GuardParamType[] memory paramTypes = new GuardParamType[](1);
        paramTypes[0] = GuardParamType.Owner;

        GuardDefinition[][] memory guards = new GuardDefinition[][](2);
        guards[0] = new GuardDefinition[](1);
        guards[0][0] = GuardDefinition(
            address(mockGuard), "isWhitelisted(address)", bytes32(uint256(1)), paramTypes, new bytes[](0), "<"
        );

        RequestType[] memory requestTypes = new RequestType[](1);
        requestTypes[0] = RequestType.Deposit;

        guardManager.setGuards(address(2), guards, requestTypes);
        guardManager.runGuards(
            address(2), RequestContext(user, user, user, RequestType.Deposit, new uint256[](0), new address[](0))
        );
    }

    function test_runGuards_greaterThan() public {
        GuardParamType[] memory paramTypes = new GuardParamType[](1);
        paramTypes[0] = GuardParamType.Owner;

        GuardDefinition[][] memory guards = new GuardDefinition[][](2);
        guards[0] = new GuardDefinition[](1);
        guards[0][0] = GuardDefinition(
            address(mockGuard), "isWhitelisted(address)", bytes32(uint256(0)), paramTypes, new bytes[](0), ">"
        );

        RequestType[] memory requestTypes = new RequestType[](1);
        requestTypes[0] = RequestType.Deposit;

        guardManager.setGuards(address(2), guards, requestTypes);

        vm.expectRevert(abi.encodeWithSelector(GuardFailed.selector, 0));
        guardManager.runGuards(
            address(2), RequestContext(user, user, user, RequestType.Deposit, new uint256[](0), new address[](0))
        );
    }

    function test_runGuards_lessThanOrEqual() public {
        GuardParamType[] memory paramTypes = new GuardParamType[](1);
        paramTypes[0] = GuardParamType.Owner;

        GuardDefinition[][] memory guards = new GuardDefinition[][](2);
        guards[0] = new GuardDefinition[](1);
        guards[0][0] = GuardDefinition(
            address(mockGuard), "isWhitelisted(address)", bytes32(uint256(0)), paramTypes, new bytes[](0), "<="
        );

        RequestType[] memory requestTypes = new RequestType[](1);
        requestTypes[0] = RequestType.Deposit;

        guardManager.setGuards(address(2), guards, requestTypes);
        guardManager.runGuards(
            address(2), RequestContext(user, user, user, RequestType.Deposit, new uint256[](0), new address[](0))
        );
    }

    function test_writeGuards() public {
        (GuardDefinition[][] memory guards, RequestType[] memory requestTypes) = _createGuards();

        guardManager.setGuards(address(2), guards, requestTypes);
    }
}
