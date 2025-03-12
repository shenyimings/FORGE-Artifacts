// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/managers/RiskManager.sol";
import "../src/access/SpoolAccessControl.sol";
import "./libraries/Arrays.sol";

contract RiskManagerTest is Test {
    using uint16a16Lib for uint16a16;

    IRiskManager riskManager;
    SpoolAccessControl accessControl;
    address riskProvider = address(10);
    address allocationProvider = address(11);
    address smartVault = address(100);
    address actor = actor;
    address strategyRegistry = address(0x0101);

    function setUp() public {
        accessControl = new SpoolAccessControl();
        accessControl.initialize();

        riskManager = new RiskManager(accessControl, IStrategyRegistry(strategyRegistry), address(0xabc));
    }

    function test_calculateAllocation() public {
        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, address(this));
        accessControl.grantRole(ROLE_ALLOCATION_PROVIDER, allocationProvider);
        accessControl.grantRole(ROLE_RISK_PROVIDER, STATIC_RISK_PROVIDER);

        riskManager.setAllocationProvider(smartVault, allocationProvider);
        riskManager.setRiskProvider(smartVault, STATIC_RISK_PROVIDER);

        vm.mockCall(
            strategyRegistry,
            abi.encodeWithSelector(IStrategyRegistry.strategyAPYs.selector),
            abi.encode(Arrays.toArray(10_00, 10_00))
        );

        vm.mockCall(
            allocationProvider,
            abi.encodeWithSelector(IAllocationProvider.calculateAllocation.selector),
            abi.encode(Arrays.toArray(40_00, 60_00))
        );

        uint16a16 allocations =
            riskManager.calculateAllocation(smartVault, Arrays.toArray(address(0x0101), address(0x0102)));

        assertEq(allocations.get(0), 40_00);
        assertEq(allocations.get(1), 60_00);
        assertEq(allocations.get(2), 0);
    }

    function test_setRiskScore_success() public {
        address[] memory strategies = Arrays.toArray(address(1), address(2));
        uint8[] memory riskScores = new uint8[](2);
        riskScores[0] = 1_0;
        riskScores[1] = 2_0;

        accessControl.grantRole(ROLE_RISK_PROVIDER, riskProvider);

        vm.prank(riskProvider);
        riskManager.setRiskScores(riskScores, strategies);

        riskScores = riskManager.getRiskScores(riskProvider, strategies);
        assertEq(riskScores.length, 2);
        assertEq(riskScores[0], 1_0);
        assertEq(riskScores[1], 2_0);
    }

    function test_setRiskScore_missingRole() public {
        address[] memory strategies = Arrays.toArray(address(1), address(2));
        uint8[] memory riskScores = new uint8[](2);
        riskScores[0] = 1_0;
        riskScores[1] = 2_0;

        vm.prank(riskProvider);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_RISK_PROVIDER, riskProvider));
        riskManager.setRiskScores(riskScores, strategies);
    }

    function test_setRiskScore_revertOutOfBounds() public {
        address[] memory strategies = Arrays.toArray(address(1), address(2));
        uint8[] memory riskScores = new uint8[](2);
        riskScores[0] = 150;
        riskScores[1] = 200;

        accessControl.grantRole(ROLE_RISK_PROVIDER, riskProvider);
        vm.prank(riskProvider);
        vm.expectRevert(abi.encodeWithSelector(RiskScoreValueOutOfBounds.selector, 150));
        riskManager.setRiskScores(riskScores, strategies);
    }

    function test_setRiskScore_revertInvalidInputLength() public {
        address[] memory strategies = Arrays.toArray(address(1));
        uint8[] memory riskScores = new uint8[](2);
        riskScores[0] = 150;
        riskScores[1] = 200;

        accessControl.grantRole(ROLE_RISK_PROVIDER, riskProvider);
        vm.prank(riskProvider);
        vm.expectRevert(abi.encodeWithSelector(InvalidRiskInputLength.selector));
        riskManager.setRiskScores(riskScores, strategies);
    }

    function test_setRiskProvider_success() public {
        accessControl.grantRole(ROLE_RISK_PROVIDER, riskProvider);
        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, actor);
        vm.prank(actor);
        riskManager.setRiskProvider(smartVault, riskProvider);

        assertEq(riskManager.getRiskProvider(smartVault), riskProvider);
    }

    function test_setRiskProvider_revertMissingRole() public {
        accessControl.grantRole(ROLE_RISK_PROVIDER, riskProvider);
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SMART_VAULT_INTEGRATOR, actor));
        riskManager.setRiskProvider(smartVault, riskProvider);
    }

    function test_setRiskProvider_revertInvalidProvider() public {
        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, actor);
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_RISK_PROVIDER, riskProvider));
        riskManager.setRiskProvider(smartVault, riskProvider);
    }

    function test_setAllocationProvider_success() public {
        accessControl.grantRole(ROLE_ALLOCATION_PROVIDER, allocationProvider);
        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, actor);
        vm.prank(actor);
        riskManager.setAllocationProvider(smartVault, allocationProvider);

        assertEq(riskManager.getAllocationProvider(smartVault), allocationProvider);
    }

    function test_setAllocationProvider_revertMissingRole() public {
        accessControl.grantRole(ROLE_ALLOCATION_PROVIDER, allocationProvider);
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SMART_VAULT_INTEGRATOR, actor));
        riskManager.setAllocationProvider(smartVault, allocationProvider);
    }

    function test_setAllocationProvider_revertInvalidProvider() public {
        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, actor);
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_ALLOCATION_PROVIDER, allocationProvider));
        riskManager.setAllocationProvider(smartVault, allocationProvider);
    }

    function test_setRiskTolerance_success() public {
        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, actor);
        vm.prank(actor);
        riskManager.setRiskTolerance(smartVault, 1_0);

        assertEq(riskManager.getRiskTolerance(smartVault), 1_0);
    }

    function test_setRiskTolerance_revertMissingRole() public {
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SMART_VAULT_INTEGRATOR, actor));
        riskManager.setRiskTolerance(smartVault, 1_0);
    }

    function test_setRiskTolerance_revertRiskToleranceOutOfBounds() public {
        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, actor);
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSelector(RiskToleranceValueOutOfBounds.selector, 12));
        riskManager.setRiskTolerance(smartVault, 12);
    }
}
