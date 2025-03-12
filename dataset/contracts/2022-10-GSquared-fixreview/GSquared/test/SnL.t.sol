// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.GSquared.t.sol";
import "../contracts/solmate/src/utils/SafeTransferLib.sol";
import {GuardErrors} from "../contracts/strategy/keeper/GStrategyGuard.sol";

contract SnLTest is BaseSetup {
    uint256 constant MIN_REPORT_DELAY = 172801;
    uint256 constant MAX_REPORT_DELAY = 604801;
    uint256 constant LARGE_AMOUNT = 1E26;
    uint64 constant HOUR_IN_SECONDS = 3600;
    uint256 constant HARVEST_MIN = 21E21;

    address frax_lp = address(0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);
    address frax = address(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    address fraxConvexPool =
        address(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address fraxConvexRewards =
        address(0xB900EF131301B307dB5eFcbed9DBb50A3e209B2e);
    uint256 frax_lp_pid = 32;

    address musd_lp = address(0x1AEf73d49Dedc4b1778d0706583995958Dc862e6);
    address musd_curve = address(0x8474DdbE98F5aA3179B3B3F5942D724aFcdec9f6);
    address musd = address(0xe2f2a5C287993345a840Db3B0845fbC70f5935a5);
    address musdConvexPool =
        address(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address musdConvexRewards =
        address(0xDBFa6187C79f4fE4Cda20609E75760C5AaE88e52);
    uint256 musd_lp_pid = 14;

    address mim_lp = address(0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
    address mim = address(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    address mimConvexPool = address(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address mimConvexRewards =
        address(0xFd5AbF66b003881b88567EB9Ed9c651F14Dc4771);
    uint256 mim_lp_pid = 40;

    using stdStorage for StdStorage;

    ConvexStrategy fraxStrategy;
    ConvexStrategy musdStrategy;
    ConvexStrategy mimStrategy;

    GStrategyGuard guard;
    GStopLossResolver resolver;
    StopLossLogic snl;

    function setUp() public virtual override {
        BaseSetup.setUp();

        vm.startPrank(BASED_ADDRESS);
        fraxStrategy = new ConvexStrategy(
            IGVault(address(gVault)),
            BASED_ADDRESS,
            frax_lp_pid,
            frax_lp
        );
        musdStrategy = new ConvexStrategy(
            IGVault(address(gVault)),
            BASED_ADDRESS,
            musd_lp_pid,
            musd_curve
        );
        mimStrategy = new ConvexStrategy(
            IGVault(address(gVault)),
            BASED_ADDRESS,
            mim_lp_pid,
            mim_lp
        );
        snl = new StopLossLogic();

        fraxStrategy.setStopLossLogic(address(snl));
        musdStrategy.setStopLossLogic(address(snl));
        mimStrategy.setStopLossLogic(address(snl));

        fraxStrategy.setBaseSlippage(20);
        musdStrategy.setBaseSlippage(20);
        mimStrategy.setBaseSlippage(20);

        snl.setStrategy(address(fraxStrategy), 1e18, 400);
        snl.setStrategy(address(musdStrategy), 1e18, 400);
        snl.setStrategy(address(mimStrategy), 1e18, 400);

        fraxStrategy.setKeeper(BASED_ADDRESS);
        musdStrategy.setKeeper(BASED_ADDRESS);
        mimStrategy.setKeeper(BASED_ADDRESS);

        gVault.removeStrategy(address(strategy));
        gVault.addStrategy(address(fraxStrategy), 3000);
        gVault.addStrategy(address(musdStrategy), 3000);
        gVault.addStrategy(address(mimStrategy), 3000);

        guard = new GStrategyGuard();
        guard.setKeeper(BASED_ADDRESS);
        resolver = new GStopLossResolver(address(guard));

        fraxStrategy.setKeeper(address(guard));
        musdStrategy.setKeeper(address(guard));
        mimStrategy.setKeeper(address(guard));

        guard.addStrategy(address(fraxStrategy), HOUR_IN_SECONDS);
        guard.addStrategy(address(musdStrategy), HOUR_IN_SECONDS);
        guard.addStrategy(address(mimStrategy), HOUR_IN_SECONDS);
        vm.stopPrank();

        uint256 shares = depositIntoVault(alice, 1E24);

        vm.startPrank(BASED_ADDRESS);
        fraxStrategy.runHarvest();
        mimStrategy.runHarvest();
        musdStrategy.runHarvest();
        vm.stopPrank();

        vm.label(address(fraxStrategy), "Frax Strategy");
        vm.label(address(musdStrategy), "mUSD Strategy");
        vm.label(address(mimStrategy), "mim Strategy");
    }

    function testGuardSetDebtThreshold() public {
        uint256 initialThreshold = guard.debtThreshold();
        vm.prank(BASED_ADDRESS);
        guard.setDebtThreshold(1000);
        assertEq(guard.debtThreshold(), 1000);
        assertTrue(initialThreshold != guard.debtThreshold());
    }

    function testGuardSetDebtThresholdNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(GuardErrors.NotOwner.selector));
        guard.setDebtThreshold(1000);
    }

    function testGuardSetGasThreshold() public {
        uint256 initialThreshold = guard.gasThreshold();
        vm.prank(BASED_ADDRESS);
        guard.setGasThreshold(1000);
        assertEq(guard.gasThreshold(), 1000);
        assertTrue(initialThreshold != guard.gasThreshold());
    }

    function testGuardSetGasThresholdNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(GuardErrors.NotOwner.selector));
        guard.setGasThreshold(1000);
    }

    // GIVEN a convex strategy not added to the stop loss logic
    // WHEN the stop loss check is run
    // THEN the logic should return false
    function test_guard_should_return_false_if_when_no_threshold_breached()
        public
    {
        vm.startPrank(BASED_ADDRESS);
        ConvexStrategy testStrategy = new ConvexStrategy(
            IGVault(address(gVault)),
            BASED_ADDRESS,
            frax_lp_pid,
            frax_lp
        );
        testStrategy.setKeeper(BASED_ADDRESS);
        guard.addStrategy(address(testStrategy), HOUR_IN_SECONDS);
        gVault.addStrategy(address(testStrategy), 1000);

        assertTrue(!guard.canHarvest());
        assertTrue(!guard.canUpdateStopLoss());
        assertTrue(!guard.canEndStopLoss());
        assertTrue(!guard.canExecuteStopLossPrimer());
    }

    // Harvest
    function test_guard_should_return_false_multiple_strategies_no_threshold_broken_harvest()
        public
    {
        assertTrue(!guard.canHarvest());
    }

    function test_guard_should_returns_true_multiple_strategies_one_broken_treshold_harvest()
        public
    {
        uint256 shares = genThreeCrv(1E24, alice);
        vm.startPrank(alice);
        vm.warp(block.timestamp + MIN_REPORT_DELAY);
        THREE_POOL_TOKEN.transfer(address(fraxStrategy), shares);
        assertTrue(fraxStrategy.canHarvest());
        assertTrue(guard.canHarvest());
        vm.stopPrank();
    }

    function test_guard_should_execute_if_threshold_broken_one_strategy()
        public
    {
        uint256 shares = genThreeCrv(1E24, alice);
        vm.startPrank(alice);
        THREE_POOL_TOKEN.transfer(address(fraxStrategy), HARVEST_MIN);
        vm.stopPrank();

        vm.startPrank(BASED_ADDRESS);
        assertTrue(!fraxStrategy.canHarvest());
        assertTrue(!guard.canHarvest());

        vm.warp(block.timestamp + MIN_REPORT_DELAY);

        assertTrue(fraxStrategy.canHarvest());
        assertTrue(guard.canHarvest());

        guard.harvest();

        assertFalse(fraxStrategy.canHarvest());
        assertFalse(guard.canHarvest());
        vm.stopPrank();
    }

    function testGuardShouldNotExecuteIfGasPriceTooHigh() public {
        uint256 shares = genThreeCrv(1E24, alice);
        vm.startPrank(alice);
        THREE_POOL_TOKEN.transfer(address(fraxStrategy), HARVEST_MIN);
        vm.stopPrank();

        assertFalse(fraxStrategy.canHarvest());
        assertFalse(guard.canHarvest());

        vm.warp(block.timestamp + MIN_REPORT_DELAY);
        // Set gas price to a lot of gwei
        vm.txGasPrice(100000100000100000e9);
        // Strategy should return true but the guard won't let harvest happen because of gas price
        assertTrue(fraxStrategy.canHarvest());
        assertFalse(guard.canHarvest());
    }

    function testGuardShoudLetExecuteIfGasPriceIsHighButThereIsLoss() public {
        assertFalse(fraxStrategy.canHarvest());
        assertFalse(guard.canHarvest());
        // Give lots of frax to alice
        genStable(10000000000e18, frax, alice);

        // Swap frax to 3crv to incur loss on strategy
        vm.startPrank(alice);
        IERC20(frax).approve(frax_lp, type(uint256).max);
        uint256 amount = ICurveMeta(frax_lp).exchange(0, 1, 10000000000e18, 0);
        vm.stopPrank();

        // Set gas price to over 90000 gwei
        vm.txGasPrice(100000100000100000e9);
        // Should be able to execute if there is loss even if gas price is high, because there is a big loss
        assertTrue(fraxStrategy.canHarvest());
        assertTrue(guard.canHarvest());
    }

    function testGuardShouldMarkStrategyLockedLossPersists() public {
        uint256 amountToSwap = 10000000000e18;
        assertFalse(fraxStrategy.canHarvest());
        assertFalse(guard.canHarvest());
        // Give lots of frax to alice
        genStable(amountToSwap, frax, alice);

        // Swap frax to 3crv to incur loss on strategy
        vm.startPrank(alice);
        IERC20(frax).approve(frax_lp, type(uint256).max);
        uint256 amount = ICurveMeta(frax_lp).exchange(0, 1, amountToSwap, 0);
        vm.stopPrank();

        vm.prank(BASED_ADDRESS);
        guard.harvest();
        (, bool canHarvestWithLoss, uint256 lossStartBlock, , ) = guard
            .strategyCheck(address(fraxStrategy));
        // Make sure strategy marked as locked
        assertFalse(canHarvestWithLoss);
        assertGt(lossStartBlock, 0);
        assertFalse(guard.canHarvest());

        // Check that strategy cannot be unlocked
        (bool canUnlock, ) = guard.canUnlockStrategy();
        assertFalse(canUnlock);
        // Now mine X amount of blocks and strategy can now be harvested even with loss
        vm.roll(block.number + guard.LOSS_BLOCK_THRESHOLD() + 1);
        (canUnlock, ) = guard.canUnlockStrategy();
        assertTrue(canUnlock);

        // Unlock the strategy:
        vm.prank(BASED_ADDRESS);
        guard.unlockLoss(address(fraxStrategy));

        // Make sure we can harvest now:
        assertTrue(guard.canHarvest());
        assertTrue(fraxStrategy.canHarvest());
        (, canHarvestWithLoss, lossStartBlock, , ) = guard.strategyCheck(
            address(fraxStrategy)
        );
        assertTrue(canHarvestWithLoss);
        assertGt(lossStartBlock, 0);

        // Run harvest
        vm.prank(BASED_ADDRESS);
        guard.harvest();
        assertFalse(fraxStrategy.canHarvest());
        // Make sure frax lock is reset:
        (, canHarvestWithLoss, lossStartBlock, , ) = guard.strategyCheck(
            address(fraxStrategy)
        );
        assertFalse(canHarvestWithLoss);
        assertEq(lossStartBlock, 0);
    }

    function testGuardShouldMarkStrategyLockedLossVanishes() public {
        uint256 amountToSwap = 10000000000e18;
        assertFalse(fraxStrategy.canHarvest());
        assertFalse(guard.canHarvest());
        // Give lots of frax to alice
        genStable(amountToSwap, frax, alice);

        // Swap frax to 3crv to incur loss on strategy
        vm.startPrank(alice);
        IERC20(frax).approve(frax_lp, type(uint256).max);
        THREE_POOL_TOKEN.approve(frax_lp, type(uint256).max);
        uint256 amount = ICurveMeta(frax_lp).exchange(0, 1, amountToSwap, 0);
        vm.stopPrank();

        vm.prank(BASED_ADDRESS);
        guard.harvest();
        (, bool canHarvestWithLoss, uint256 lossStartBlock, , ) = guard
            .strategyCheck(address(fraxStrategy));
        // Make sure strategy marked as locked
        assertFalse(canHarvestWithLoss);
        assertGt(lossStartBlock, 0);
        assertFalse(guard.canHarvest());

        // Check that strategy cannot be unlocked
        (bool canUnlock, ) = guard.canUnlockStrategy();
        assertFalse(canUnlock);
        // Now, remove the loss
        vm.prank(alice);
        ICurveMeta(frax_lp).exchange(1, 0, amount, 0);

        vm.prank(BASED_ADDRESS);
        guard.resetLossStartBlock(address(fraxStrategy));
        // Make sure strategy is unlocked now as loss is gone and values are set to defaults
        (, canHarvestWithLoss, lossStartBlock, , ) = guard.strategyCheck(
            address(fraxStrategy)
        );
        assertFalse(canHarvestWithLoss);
        assertEq(lossStartBlock, 0);

        // Make sure we can harvest now:
        vm.warp(block.timestamp + 604800 + 1);
        assertTrue(guard.canHarvest());
        assertTrue(fraxStrategy.canHarvest());
    }

    function test_guard_should_execute_if_threshold_broken_and_return_true_if_credit_available()
        public
    {
        uint256 shares = depositIntoVault(alice, 1E25);

        vm.warp(block.timestamp + MIN_REPORT_DELAY);

        vm.startPrank(BASED_ADDRESS);

        assertTrue(fraxStrategy.canHarvest());
        assertTrue(guard.canHarvest());
        guard.harvest();
        // Frax can still be harvested because it was marked as locked because it has debt
        assertTrue(fraxStrategy.canHarvest());
        // credit available for other strategies
        assertTrue(mimStrategy.canHarvest());
        assertTrue(musdStrategy.canHarvest());
        assertTrue(guard.canHarvest());
        vm.stopPrank();
    }

    function test_guard_should_returns_true_after_execute_if_multiple_strategy_thresholds_broken()
        public
    {
        uint256 shares = genThreeCrv(1E26, alice);
        vm.startPrank(alice);
        THREE_POOL_TOKEN.transfer(address(fraxStrategy), HARVEST_MIN);
        THREE_POOL_TOKEN.transfer(address(mimStrategy), HARVEST_MIN);
        THREE_POOL_TOKEN.transfer(address(musdStrategy), HARVEST_MIN);
        vm.stopPrank();

        vm.warp(block.timestamp + MIN_REPORT_DELAY);

        vm.startPrank(BASED_ADDRESS);

        assertTrue(fraxStrategy.canHarvest());
        assertTrue(mimStrategy.canHarvest());
        assertTrue(musdStrategy.canHarvest());
        assertTrue(guard.canHarvest());

        guard.harvest();

        assertTrue(!fraxStrategy.canHarvest());
        assertTrue(mimStrategy.canHarvest());
        assertTrue(musdStrategy.canHarvest());
        assertTrue(guard.canHarvest());
        vm.stopPrank();
    }

    // Stop loss
    function test_guard_should_return_false_multiple_strategies_no_threshold_broken_stop_loss()
        public
    {
        assertTrue(!guard.canUpdateStopLoss());
        assertTrue(!guard.canEndStopLoss());
        assertTrue(!guard.canExecuteStopLossPrimer());
    }

    function test_guard_should_returns_true_multiple_strategies_one_broken_treshold_stop_loss()
        public
    {
        manipulatePool(false, 500, frax_lp, frax);
        assertTrue(guard.canUpdateStopLoss());
        assertTrue(!guard.canEndStopLoss());
        assertTrue(!guard.canExecuteStopLossPrimer());
    }

    function test_guard_should_execute_if_threshold_broken_stop_loss() public {
        manipulatePool(false, 500, frax_lp, frax);

        assertTrue(fraxStrategy.canStopLoss());
        assertTrue(guard.canUpdateStopLoss());

        vm.startPrank(BASED_ADDRESS);
        guard.setStopLossPrimer();

        assertTrue(fraxStrategy.canStopLoss());
        assertTrue(!guard.canUpdateStopLoss());
        assertTrue(!guard.canEndStopLoss());
        assertTrue(!guard.canExecuteStopLossPrimer());

        vm.stopPrank();
    }

    function test_guard_should_return_true_multiple_strategies_multiple_thresholds_broken()
        public
    {
        manipulatePool(false, 500, frax_lp, frax);
        manipulatePool(false, 5000, mim_lp, mim);

        assertTrue(fraxStrategy.canStopLoss());
        assertTrue(mimStrategy.canStopLoss());
        assertTrue(guard.canUpdateStopLoss());

        vm.startPrank(BASED_ADDRESS);
        guard.setStopLossPrimer();

        assertTrue(fraxStrategy.canStopLoss());
        assertTrue(mimStrategy.canStopLoss());
        assertTrue(guard.canUpdateStopLoss());
        assertTrue(!guard.canEndStopLoss());
        assertTrue(!guard.canExecuteStopLossPrimer());

        vm.stopPrank();
    }

    function test_guard_should_reset_stop_loss_primer_if_returned_within_threshold()
        public
    {
        (uint256 crvFraxSwap, ) = manipulatePoolSmallerTokenAmount(
            false,
            9000,
            frax_lp,
            frax
        );
        (uint256 crvMimSwap, ) = manipulatePoolSmallerTokenAmount(
            false,
            5000,
            mim_lp,
            mim
        );

        assertTrue(fraxStrategy.canStopLoss());
        assertTrue(mimStrategy.canStopLoss());

        vm.startPrank(BASED_ADDRESS);

        guard.setStopLossPrimer();
        guard.setStopLossPrimer();

        assertTrue(fraxStrategy.canStopLoss());
        assertTrue(mimStrategy.canStopLoss());

        assertTrue(!guard.canUpdateStopLoss());
        assertTrue(!guard.canEndStopLoss());

        vm.stopPrank();

        reverseManipulation(
            true,
            crvFraxSwap,
            frax_lp,
            address(THREE_POOL_TOKEN)
        );
        reverseManipulation(
            true,
            crvMimSwap,
            mim_lp,
            address(THREE_POOL_TOKEN)
        );

        bool active; // Is the strategy active
        uint64 timeLimit;
        uint64 primerTimestamp; // The time at which the health threshold was broken

        assertTrue(!fraxStrategy.canStopLoss());
        (, , , , primerTimestamp) = guard.strategyCheck(address(fraxStrategy));
        assertGt(primerTimestamp, 0);
        assertTrue(guard.canEndStopLoss());

        vm.startPrank(BASED_ADDRESS);
        guard.endStopLossPrimer();

        (, , , , primerTimestamp) = guard.strategyCheck(address(fraxStrategy));
        assertEq(primerTimestamp, 0);
        (, , , , primerTimestamp) = guard.strategyCheck(address(mimStrategy));
        assertGt(primerTimestamp, 0);
        assertTrue(guard.canEndStopLoss());
        vm.stopPrank();
    }

    function test_guard_should_execute_stop_loss_after_designated_time()
        public
    {
        manipulatePool(false, 50, mim_lp, mim);

        vm.startPrank(BASED_ADDRESS);
        fraxStrategy.setBaseSlippage(5000);
        mimStrategy.setBaseSlippage(5000);

        mimStrategy.runHarvest();
        fraxStrategy.runHarvest();
        musdStrategy.runHarvest();
        vm.stopPrank();

        manipulatePool(false, 50, frax_lp, frax);
        vm.startPrank(BASED_ADDRESS);

        mimStrategy.runHarvest();
        fraxStrategy.runHarvest();
        musdStrategy.runHarvest();
        fraxStrategy.setBaseSlippage(50);
        mimStrategy.setBaseSlippage(50);
        assertTrue(mimStrategy.canStopLoss());
        assertTrue(guard.canUpdateStopLoss());

        guard.setStopLossPrimer();
        guard.setStopLossPrimer();

        assertTrue(fraxStrategy.canStopLoss());
        assertTrue(mimStrategy.canStopLoss());
        assertTrue(!guard.canUpdateStopLoss());
        assertTrue(!guard.canExecuteStopLossPrimer());

        vm.warp(block.timestamp + MIN_REPORT_DELAY);

        assertTrue(guard.canExecuteStopLossPrimer());
        assertTrue(fraxStrategy.canStopLoss());

        uint256 stopLossAttempts = fraxStrategy.stopLossAttempts();
        while (true) {
            guard.executeStopLoss();
            if (fraxStrategy.canStopLoss()) {
                stopLossAttempts = stopLossAttempts + 1;
                assertEq(fraxStrategy.stopLossAttempts(), stopLossAttempts);
                continue;
            }
            assertEq(fraxStrategy.stopLossAttempts(), 0);
            assertTrue(fraxStrategy.stop());
            break;
        }

        assertTrue(!fraxStrategy.canStopLoss());
        assertEq(ERC20(frax_lp).balanceOf(address(fraxStrategy)), 0);
        assertEq(
            fraxStrategy.estimatedTotalAssets(),
            THREE_POOL_TOKEN.balanceOf(address(fraxStrategy))
        );
        uint64 primerTimestamp;
        bool active;
        (active, , , , primerTimestamp) = guard.strategyCheck(
            address(fraxStrategy)
        );
        assertEq(primerTimestamp, 0);
        assertTrue(!active);

        assertTrue(guard.canExecuteStopLossPrimer());
        assertTrue(mimStrategy.canStopLoss());

        stopLossAttempts = mimStrategy.stopLossAttempts();
        while (true) {
            guard.executeStopLoss();
            if (mimStrategy.canStopLoss()) {
                stopLossAttempts = stopLossAttempts + 1;
                assertEq(mimStrategy.stopLossAttempts(), stopLossAttempts);
                continue;
            }
            assertEq(mimStrategy.stopLossAttempts(), 0);
            assertTrue(mimStrategy.stop());
            break;
        }
        assertTrue(!mimStrategy.canStopLoss());
        assertEq(ERC20(mim_lp).balanceOf(address(mimStrategy)), 0);
        assertEq(
            mimStrategy.estimatedTotalAssets(),
            THREE_POOL_TOKEN.balanceOf(address(mimStrategy))
        );

        (active, , , , primerTimestamp) = guard.strategyCheck(
            address(mimStrategy)
        );
        assertEq(primerTimestamp, 0);
        assertTrue(!active);

        assertTrue(!guard.canExecuteStopLossPrimer());
        assertTrue(!guard.canUpdateStopLoss());
        assertTrue(!guard.canEndStopLoss());
        assertTrue(!guard.canHarvest());
        vm.stopPrank();
    }

    // GIVEN a convex strategy not added to the stop loss logic
    // WHEN the stop loss check is run
    // THEN the logic should return false
    function test_stop_loss_should_returns_false_if_strategy_not_added()
        public
    {
        vm.startPrank(address(fraxStrategy));
        assertTrue(!snl.stopLossCheck());
        vm.stopPrank();
    }

    // GIVEN a convex strategy
    // WHEN the added to the stop loss logic
    // THEN the stop loss logic should hold the strategy data
    function test_stop_loss_add_strategy() public {
        vm.startPrank(BASED_ADDRESS);
        ConvexStrategy testStrategy = new ConvexStrategy(
            IGVault(address(gVault)),
            BASED_ADDRESS,
            frax_lp_pid,
            frax_lp
        );
        gVault.addStrategy(address(testStrategy), 1000);
        vm.stopPrank();

        vm.startPrank(address(testStrategy));
        assertTrue(!snl.stopLossCheck());
        vm.stopPrank();

        uint128 eq;
        (eq, ) = snl.strategyData(address(testStrategy));
        assertEq(eq, 0);

        vm.startPrank(BASED_ADDRESS);
        snl.setStrategy(address(testStrategy), 1e18, 400);
        vm.stopPrank();
        (eq, ) = snl.strategyData(address(testStrategy));
        assertEq(eq, 1e18);
        vm.startPrank(address(testStrategy));
        assertTrue(!snl.stopLossCheck());
        vm.stopPrank();
    }

    // GIVEN a convex strategy added to the stop loss logic
    // WHEN the underlying pool balance is outside the health threshold
    // THEN the stop loss logic should return true
    function test_stop_loss_should_returns_true_if_outside_threshold() public {
        vm.startPrank(address(fraxStrategy));
        assertTrue(!snl.stopLossCheck());
        vm.stopPrank();

        vm.startPrank(BASED_ADDRESS);
        snl.setStrategy(address(fraxStrategy), 1, 400);
        vm.stopPrank();

        vm.startPrank(address(fraxStrategy));
        assertTrue(snl.stopLossCheck());
        vm.stopPrank();
    }

    // GIVEN a convex strategy added to the stop loss logic
    // WHEN the underlying pool balance moves outside the health threshold
    // THEN the stop loss logic should return true
    function test_stop_loss_should_return_true_if_moving_outside_threshold()
        public
    {
        vm.startPrank(BASED_ADDRESS);
        snl.setStrategy(address(fraxStrategy), 1e18, 400);
        vm.stopPrank();

        vm.startPrank(address(fraxStrategy));
        assertTrue(!snl.stopLossCheck());
        vm.stopPrank();
        manipulatePool(false, 500, frax_lp, frax);
        vm.startPrank(address(fraxStrategy));
        assertTrue(snl.stopLossCheck());
        vm.stopPrank();
    }
}
