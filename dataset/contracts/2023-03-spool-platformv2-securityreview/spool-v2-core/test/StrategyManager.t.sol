// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/interfaces/IStrategyRegistry.sol";
import "../src/managers/StrategyRegistry.sol";
import "../src/MasterWallet.sol";
import "./libraries/Arrays.sol";
import "../src/Swapper.sol";
import "./mocks/MockPriceFeedManager.sol";
import "../src/strategies/GhostStrategy.sol";
import "../src/access/SpoolAccessControl.sol";

contract StrategyRegistryTest is Test {
    StrategyRegistryStub strategyRegistry;
    SpoolAccessControl accessControl;

    function setUp() public {
        accessControl = new SpoolAccessControl();
        accessControl.initialize();
        strategyRegistry =
        new StrategyRegistryStub(new MasterWallet(accessControl), accessControl, new MockPriceFeedManager(), address(new GhostStrategy()));
        strategyRegistry.initialize(5_00, 5_00, address(0xc), address(0xc), address(0xb));

        accessControl.grantRole(ADMIN_ROLE_STRATEGY, address(strategyRegistry));
    }

    function test_registerStrategy() public {
        address strategy = address(new MockStrategy());
        assertFalse(accessControl.hasRole(ROLE_STRATEGY, strategy));

        strategyRegistry.registerStrategy(strategy);
        assertTrue(accessControl.hasRole(ROLE_STRATEGY, strategy));

        vm.expectRevert(abi.encodeWithSelector(StrategyAlreadyRegistered.selector, strategy));
        strategyRegistry.registerStrategy(strategy);
    }

    function test_removeStrategy_revertNotVaultManager() public {
        address strategy = address(new MockStrategy());

        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SMART_VAULT_MANAGER, address(this)));
        strategyRegistry.removeStrategy(strategy);
    }

    function test_removeStrategy_revertInvalidStrategy() public {
        address strategy = address(new MockStrategy());
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(this));

        vm.expectRevert(abi.encodeWithSelector(InvalidStrategy.selector, strategy));
        strategyRegistry.removeStrategy(strategy);
    }

    function test_removeStrategy_success() public {
        address strategy = address(new MockStrategy());
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(this));

        strategyRegistry.registerStrategy(strategy);
        assertTrue(accessControl.hasRole(ROLE_STRATEGY, strategy));

        strategyRegistry.removeStrategy(strategy);
        assertFalse(accessControl.hasRole(ROLE_STRATEGY, strategy));
    }

    function test_setEmergencyWithdrawalWallet_revertMissingRole() public {
        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SPOOL_ADMIN, address(0xa)));
        strategyRegistry.setEmergencyWithdrawalWallet(address(0xb));
    }

    function test_setEmergencyWithdrawalWallet_revertAddressZero() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));
        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(ConfigurationAddressZero.selector));
        strategyRegistry.setEmergencyWithdrawalWallet(address(0));
    }

    function test_setEmergencyWithdrawalWallet_ok() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));
        vm.prank(address(0xa));
        strategyRegistry.setEmergencyWithdrawalWallet(address(0xb));

        assertEq(strategyRegistry.emergencyWithdrawalWallet(), address(0xb));
    }

    function test_setEcosystemFee_revertMissingRole() public {
        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SPOOL_ADMIN, address(0xa)));
        strategyRegistry.setEcosystemFee(10_00);
    }

    function test_setEcosystemFee_ok() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));

        vm.prank(address(0xa));
        strategyRegistry.setEcosystemFee(10_00);

        assertEq(strategyRegistry.platformFees().ecosystemFeePct, 10_00);
    }

    function test_setEcosystemFee_revertOutOfBounds() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));

        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(EcosystemFeeTooLarge.selector, ECOSYSTEM_FEE_MAX + 10));
        strategyRegistry.setEcosystemFee(uint96(ECOSYSTEM_FEE_MAX + 10));
    }

    function test_setTreasuryFee_revertMissingRole() public {
        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SPOOL_ADMIN, address(0xa)));
        strategyRegistry.setTreasuryFee(10_00);
    }

    function test_setTreasuryFee_ok() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));

        vm.prank(address(0xa));
        strategyRegistry.setTreasuryFee(10_00);

        assertEq(strategyRegistry.platformFees().treasuryFeePct, 10_00);
    }

    function test_setTreasuryFee_revertOutOfBounds() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));

        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(TreasuryFeeTooLarge.selector, TREASURY_FEE_MAX + 10));
        strategyRegistry.setTreasuryFee(uint96(TREASURY_FEE_MAX + 10));
    }

    function test_setTreasuryFeeReceiver_revertMissingRole() public {
        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SPOOL_ADMIN, address(0xa)));
        strategyRegistry.setTreasuryFeeReceiver(address(0xb));
    }

    function test_setTreasuryFeeReceiver_revertAddressZero() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));

        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(ConfigurationAddressZero.selector));
        strategyRegistry.setTreasuryFeeReceiver(address(0));
    }

    function test_setTreasuryFeeReceiver_ok() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));

        vm.prank(address(0xa));
        strategyRegistry.setTreasuryFeeReceiver(address(0xb));

        assertEq(strategyRegistry.platformFees().treasuryFeeReceiver, address(0xb));
    }

    function test_setEcosystemFeeReceiver_revertMissingRole() public {
        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SPOOL_ADMIN, address(0xa)));
        strategyRegistry.setEcosystemFeeReceiver(address(0xb));
    }

    function test_setEcosystemFeeReceiver_revertAddressZero() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));

        vm.prank(address(0xa));
        vm.expectRevert(abi.encodeWithSelector(ConfigurationAddressZero.selector));
        strategyRegistry.setEcosystemFeeReceiver(address(0));
    }

    function test_setEcosystemFeeReceiver_ok() public {
        accessControl.grantRole(ROLE_SPOOL_ADMIN, address(0xa));

        vm.prank(address(0xa));
        strategyRegistry.setEcosystemFeeReceiver(address(0xb));

        assertEq(strategyRegistry.platformFees().ecosystemFeeReceiver, address(0xb));
    }

    function test_getRunningAverageApyWeight() public {
        int256 weight = strategyRegistry.getRunningAverageApyWeight(2 hours);
        assertEq(weight, int256(4_15));

        weight = strategyRegistry.getRunningAverageApyWeight(7 hours);
        assertEq(weight, int256(12_44));

        weight = strategyRegistry.getRunningAverageApyWeight(16 hours);
        assertEq(weight, int256(24_49));

        weight = strategyRegistry.getRunningAverageApyWeight(30 hours);
        assertEq(weight, int256(35_84));

        weight = strategyRegistry.getRunningAverageApyWeight(40 hours);
        assertEq(weight, int256(46_21));

        weight = strategyRegistry.getRunningAverageApyWeight(60 hours);
        assertEq(weight, int256(63_51));

        weight = strategyRegistry.getRunningAverageApyWeight(85 hours);
        assertEq(weight, int256(76_16));

        weight = strategyRegistry.getRunningAverageApyWeight(105 hours);
        assertEq(weight, int256(84_83));

        weight = strategyRegistry.getRunningAverageApyWeight(133 hours);
        assertEq(weight, int256(90_51));

        weight = strategyRegistry.getRunningAverageApyWeight(150 hours);
        assertEq(weight, int256(94_14));

        weight = strategyRegistry.getRunningAverageApyWeight(300 hours);
        assertEq(weight, int256(FULL_PERCENT));
    }

    function test_updateDhwYieldAndApy() public {
        skip(50 weeks);
        strategyRegistry.setDhwTimestamp(address(0xa), 1, uint32(block.timestamp - 3 days));
        strategyRegistry.setAPY(address(0xa), 3_14);
        strategyRegistry.updateDhwYieldAndApy(address(0xa), 2, 5_00);

        console.logInt(strategyRegistry.strategyAPYs(Arrays.toArray(address(0xa)))[0]);
    }
}

contract MockStrategy {
    function test_mock() external pure {}

    function assetRatio() external pure returns (uint256[] memory) {
        return Arrays.toArray(1, 2);
    }
}

contract StrategyRegistryStub is StrategyRegistry {
    constructor(
        IMasterWallet masterWallet_,
        ISpoolAccessControl accessControl_,
        IUsdPriceFeedManager priceFeedManager_,
        address ghostStrategy_
    ) StrategyRegistry(masterWallet_, accessControl_, priceFeedManager_, ghostStrategy_) {}

    function updateDhwYieldAndApy(address strategy, uint256 dhwIndex, int256 yieldPercentage) external {
        return _updateDhwYieldAndApy(strategy, dhwIndex, yieldPercentage);
    }

    function getRunningAverageApyWeight(int256 timeDelta) external pure returns (int256) {
        return _getRunningAverageApyWeight(timeDelta);
    }

    function setDhwTimestamp(address strategy, uint256 dhwIndex, uint32 timestamp) external {
        _stateAtDhw[strategy][dhwIndex].timestamp = timestamp;
    }

    function setAPY(address strategy, int256 value) external {
        _apys[strategy] = value;
    }
}
