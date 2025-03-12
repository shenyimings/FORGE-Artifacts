//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/OperatorsRegistry.1.sol";
import {ITransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract OperatorsMigrationV1ToV2 is Test {
    bool internal _skip = false;

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, 16690000);
            console.log("1.operatorsMigrationV1ToV2.t.sol is active");
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    address internal constant OPERATORS_REGISTRY_MAINNET_ADDRESS = 0x1235f1b60df026B2620e48E735C422425E06b725;
    address internal constant OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS =
        0x1d1FD2d8C87Fed864708bbab84c2Da54254F5a12;

    function test_migration() external shouldSkip {
        TUPProxy orProxy = TUPProxy(payable(OPERATORS_REGISTRY_MAINNET_ADDRESS));

        OperatorsRegistryV1 newImplementation = new OperatorsRegistryV1();

        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy)).upgradeToAndCall(
            address(newImplementation), abi.encodeWithSelector(OperatorsRegistryV1.initOperatorsRegistryV1_1.selector)
        );

        OperatorsRegistryV1 or = OperatorsRegistryV1(OPERATORS_REGISTRY_MAINNET_ADDRESS);

        assertEq(or.getOperatorCount(), 3);
        assertEq(or.getTotalStoppedValidatorCount(), 0);
        {
            OperatorsV2.Operator memory op0 = or.getOperator(0);
            assertEq(op0.limit, 0);
            assertEq(op0.funded, 0);
            assertEq(op0.requestedExits, 0);
            assertEq(op0.keys, 25);
            assertEq(op0.latestKeysEditBlockNumber, 16020173);
            assertEq(op0.active, true);
            assertEq(op0.name, "Figment");
            assertEq(op0.operator, 0xDfB087180Dc5e99655Bf7e61D53dD6d25a023253);

            assertEq(or.getOperatorStoppedValidatorCount(0), 0);
        }

        {
            OperatorsV2.Operator memory op1 = or.getOperator(1);
            assertEq(op1.limit, 25);
            assertEq(op1.funded, 1);
            assertEq(op1.requestedExits, 0);
            assertEq(op1.keys, 25);
            assertEq(op1.latestKeysEditBlockNumber, 15990905);
            assertEq(op1.active, true);
            assertEq(op1.name, "Coinbase Cloud");
            assertEq(op1.operator, 0x75DC82105B5c482402A4267F628036254F380967);

            assertEq(or.getOperatorStoppedValidatorCount(1), 0);
        }

        {
            OperatorsV2.Operator memory op2 = or.getOperator(2);
            assertEq(op2.limit, 25);
            assertEq(op2.funded, 0);
            assertEq(op2.requestedExits, 0);
            assertEq(op2.keys, 25);
            assertEq(op2.latestKeysEditBlockNumber, 15991176);
            assertEq(op2.active, true);
            assertEq(op2.name, "Staked");
            assertEq(op2.operator, 0x7070CBfD67fDf8077d27548E86505F9F91C31621);

            assertEq(or.getOperatorStoppedValidatorCount(2), 0);
        }
    }
}
