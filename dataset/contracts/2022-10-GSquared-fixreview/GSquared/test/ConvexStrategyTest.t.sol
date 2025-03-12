// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.GSquared.t.sol";
import {StrategyErrors} from "../contracts/strategy/ConvexStrategy.sol";
import "../contracts/solmate/src/utils/SafeTransferLib.sol";

contract ConvexStrategyTest is BaseSetup {
    uint256 constant MIN_REPORT_DELAY = 172801;
    uint256 constant MAX_REPORT_DELAY = 604801;
    uint256 constant LARGE_AMOUNT = 10**26;
    address public constant CRV_ETH_POOL =
        address(0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511);
    ERC20 public constant CVX =
        ERC20(address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B));

    address public CVX_ETH_POOL =
        address(0xB576491F1E6e5E62f1d8F26062Ee822B40B0E0d4);
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

    using SafeTransferLib for IERC20;

    using stdStorage for StdStorage;

    address[] public tokens;

    ConvexStrategy convexStrategy;
    GStrategyGuard guard;

    function setUp() public virtual override {
        BaseSetup.setUp();

        vm.startPrank(BASED_ADDRESS);
        convexStrategy = new ConvexStrategy(
            IGVault(address(gVault)),
            BASED_ADDRESS,
            frax_lp_pid,
            frax_lp
        );
        StopLossLogic snl = new StopLossLogic();
        guard = new GStrategyGuard();
        guard.setKeeper(BASED_ADDRESS);
        convexStrategy.setStopLossLogic(address(snl));
        snl.setStrategy(address(convexStrategy), 1e18, 400);
        convexStrategy.setKeeper(BASED_ADDRESS);
        gVault.removeStrategy(address(strategy));
        gVault.addStrategy(address(convexStrategy), 10000);
        guard.addStrategy(address(strategy), 3600);
        vm.stopPrank();
    }

    ////////////////////////////////////////////
    ///////////// TEST SETTERS /////////////////
    ////////////////////////////////////////////
    /// @notice sets 3crv pool to arbitrary address
    function testSet3crvPoolHappy() public {
        // Check USDC allowance
        assertEq(
            USDC.allowance(address(convexStrategy), convexStrategy.crv3pool()),
            type(uint256).max
        );
        assertEq(
            convexStrategy.crv3pool(),
            address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7)
        );
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.set3CrvPool(musd_lp);
        assertEq(USDC.allowance(address(convexStrategy), THREE_POOL), 0);
        // Check that musd allowance is set to max
        assertEq(
            USDC.allowance(address(convexStrategy), convexStrategy.crv3pool()),
            type(uint256).max
        );
        vm.stopPrank();
        assertEq(convexStrategy.crv3pool(), musd_lp);
    }

    function testSet3crvPoolUnHappy() public {
        vm.expectRevert(
            abi.encodeWithSelector(StrategyErrors.NotOwner.selector)
        );
        convexStrategy.set3CrvPool(musd_lp);
    }

    /// @notice sets crv eth pool to arbitrary address
    function testSetCrvEthPoolHappy() public {
        // Check crv allowance
        assertEq(
            CURVE_TOKEN.allowance(
                address(convexStrategy),
                convexStrategy.crvEthPool()
            ),
            type(uint256).max
        );
        assertEq(convexStrategy.crvEthPool(), CRV_ETH_POOL);
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.setCrvEthPool(musd_lp);

        // Check curve allowance should be set to 0 now:
        assertEq(
            CURVE_TOKEN.allowance(address(convexStrategy), CRV_ETH_POOL),
            0
        );
        // Check that musd allowance is set to max
        assertEq(
            CURVE_TOKEN.allowance(
                address(convexStrategy),
                convexStrategy.crvEthPool()
            ),
            type(uint256).max
        );
        vm.stopPrank();
        assertEq(convexStrategy.crvEthPool(), musd_lp);
    }

    function testSetCrvEthPoolUnHappy() public {
        vm.expectRevert(
            abi.encodeWithSelector(StrategyErrors.NotOwner.selector)
        );
        convexStrategy.setCrvEthPool(musd_lp);
    }

    /// @notice sets cvx eth pool to arbitrary address
    function testSetCvxEthPoolHappy() public {
        // Check cvx allowance
        assertEq(
            CVX.allowance(address(convexStrategy), convexStrategy.cvxEthPool()),
            type(uint256).max
        );
        assertEq(convexStrategy.cvxEthPool(), address(CVX_ETH_POOL));
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.setCvxEthPool(musd_lp);
        // Check cvx allowance should be set to 0 now:
        assertEq(CVX.allowance(address(convexStrategy), CVX_ETH_POOL), 0);
        // Check that musd allowance is set to max
        assertEq(
            CVX.allowance(address(convexStrategy), convexStrategy.cvxEthPool()),
            type(uint256).max
        );
        vm.stopPrank();
        assertEq(convexStrategy.cvxEthPool(), musd_lp);
    }

    function testSetCvxEthPoolUnHappy() public {
        vm.expectRevert(
            abi.encodeWithSelector(StrategyErrors.NotOwner.selector)
        );
        convexStrategy.setCvxEthPool(musd_lp);
    }

    function testStrategyHarvest(uint256 deposit) public {
        vm.assume(deposit > 1E20);
        vm.assume(deposit < 1E25);

        uint256 shares = depositIntoVault(alice, deposit);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        vm.stopPrank();
    }

    function testLoss(uint128 _deposit, uint16 _loss) public {
        uint256 deposit = uint256(_deposit);
        uint256 loss = uint256(_loss);
        vm.assume(deposit > 1E20);
        vm.assume(deposit < 1E25);
        vm.assume(loss > 500);
        vm.assume(loss < 10000);

        uint256 shares = depositIntoVault(alice, deposit);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        convexStrategy.setBaseSlippage(1000);
        vm.stopPrank();

        uint256 initEstimatedAssets = convexStrategy.estimatedTotalAssets();
        uint256 initVaultAssets = gVault.realizedTotalAssets();
        manipulatePool(false, 4000, frax_lp, frax);

        assertGt(initEstimatedAssets, convexStrategy.estimatedTotalAssets());
        assertEq(initVaultAssets, gVault.realizedTotalAssets());

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();

        assertGt(initEstimatedAssets, convexStrategy.estimatedTotalAssets());
        assertGt(initVaultAssets, gVault.realizedTotalAssets());

        vm.stopPrank();
    }

    function testProfit(uint128 _deposit, uint16 _profit) public {
        uint256 deposit = uint256(_deposit);
        uint256 profit = uint256(_profit);
        vm.assume(deposit > 1E20);
        vm.assume(deposit < 1E25);
        vm.assume(profit > 500);
        vm.assume(profit < 10000);

        uint256 shares = depositIntoVault(alice, deposit);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        convexStrategy.setBaseSlippage(1000);
        vm.stopPrank();

        uint256 initEstimatedAssets = convexStrategy.estimatedTotalAssets();
        uint256 initVaultAssets = gVault.realizedTotalAssets();
        manipulatePool(true, profit, frax_lp, address(THREE_POOL_TOKEN));

        assertLt(initEstimatedAssets, convexStrategy.estimatedTotalAssets());
        assertEq(initVaultAssets, gVault.realizedTotalAssets());

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();

        assertLt(initEstimatedAssets, convexStrategy.estimatedTotalAssets());
        assertLt(initVaultAssets, gVault.realizedTotalAssets());

        vm.stopPrank();
    }

    function testUserLoss(
        uint128 _deposit,
        uint128 _withdraw,
        uint16 _loss
    ) public {
        if (_withdraw > _deposit) _withdraw = _deposit;
        uint256 withdraw = uint256(_withdraw);
        uint256 deposit = uint256(_deposit);
        uint256 loss = uint256(_loss);
        vm.assume(deposit < 1E25);
        if (deposit < 1E20) deposit = 1E20;
        if (withdraw < 1E18) withdraw = 1E18;
        vm.assume(loss > 500);
        vm.assume(loss < 4000);

        for (uint256 i; i < 4; i++) {
            address user = users[i];
            uint256 shares = depositIntoVault(user, deposit);
        }

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        convexStrategy.setBaseSlippage(1000);
        vm.stopPrank();

        uint256 initEstimatedAssets = convexStrategy.estimatedTotalAssets();
        uint256 initVaultAssets = gVault.realizedTotalAssets();
        manipulatePool(false, loss, frax_lp, frax);

        uint256 strategyLoss = (convexStrategy.estimatedTotalAssets() * 1E18) /
            initEstimatedAssets;

        for (uint256 i; i < 4; i++) {
            address user = users[i];
            vm.startPrank(user);
            (, , , uint256 strategyDebt, , ) = gVault.strategies(
                address(convexStrategy)
            );
            uint256 shares = gVault.redeem(
                withdraw,
                address(user),
                address(user)
            );
            assertApproxEqRel(shares, (withdraw * strategyLoss) / 1E18, 1E16);
            vm.stopPrank();
        }

        for (uint256 i; i < 4; i++) {
            address user = users[i];
            vm.startPrank(user);
            uint256 finalWithdraw = gVault.balanceOf(user);
            (, , , uint256 strategyDebt, , ) = gVault.strategies(
                address(convexStrategy)
            );
            uint256 shares = gVault.redeem(
                finalWithdraw,
                address(user),
                address(user)
            );
            assertApproxEqRel(
                shares,
                (finalWithdraw * strategyLoss) / 1E18,
                5E16
            );
            vm.stopPrank();
        }
        (, , , uint256 strategyDebt, , ) = gVault.strategies(
            address(convexStrategy)
        );
    }

    function test_strategy_can_invest_assets_into_convex(uint128 _deposit)
        public
    {
        uint256 deposit = uint256(_deposit);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        assertEq(convexPool.balanceOf(address(convexStrategy)), 0);
        convexStrategy.runHarvest();
        assertGt(convexPool.balanceOf(address(convexStrategy)), 0);
        vm.stopPrank();
    }

    // Test case for potential MEV attack vector
    // Given a strategy with an investment in Convex and and excess debt
    // when the metapool is severly imbalanced
    // then the harvest should revert
    function test_strategy_manipulation_during_divest_assets_from_convex_harvest()
        public
    {
        depositIntoVault(bob, 1E24);
        uint256 deposit = uint256(1E21);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        convexStrategy.runHarvest();
        uint256 initInvestment = convexPool.balanceOf(address(convexStrategy));

        gVault.setDebtRatio(address(convexStrategy), 5000);
        vm.stopPrank();
        manipulatePoolSmallerTokenAmount(false, 9500, frax_lp, address(frax));
        vm.startPrank(BASED_ADDRESS);
        // Expect to revert because of excess debt
        vm.expectRevert(
            abi.encodeWithSelector(
                StrategyErrors.ExcessDebtGtThanAssets.selector
            )
        );
        convexStrategy.runHarvest();
        // Make sure convex strategy has the same amount of assets after harvest failed
        assertApproxEqRel(
            convexPool.balanceOf(address(convexStrategy)),
            initInvestment,
            1E16
        );
        vm.stopPrank();
    }

    // Given a strategy with an investment in Convex and and excess debt
    // when the metapool is balanced
    // then the harvest should pass and pay back the excess debt
    function test_strategy_harvest_pays_back_excess_debt() public {
        depositIntoVault(bob, 1E24);
        uint256 deposit = uint256(1E21);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        convexStrategy.runHarvest();
        uint256 initInvestment = convexPool.balanceOf(address(convexStrategy));

        gVault.setDebtRatio(address(convexStrategy), 7000);
        vm.stopPrank();
        uint256 calcAmount = (initInvestment * 7000) / 10000;
        vm.startPrank(BASED_ADDRESS);
        (uint256 initExcessDebt, ) = gVault.excessDebt(address(convexStrategy));
        convexStrategy.runHarvest();
        (uint256 finalExcessDebt, ) = gVault.excessDebt(
            address(convexStrategy)
        );
        // Make sure convex strategy has the expect amount of lp tokens and less debt
        assertApproxEqRel(
            convexPool.balanceOf(address(convexStrategy)),
            calcAmount,
            1E16
        );
        assertGt(initExcessDebt, finalExcessDebt);
        vm.stopPrank();
    }

    // Test case for potential MEV attack vector
    // Given a strategy with an investment in Convex and and excess debt
    // when the metapool is partly imbalanced (assets greater than excess debt)
    // then the harvest should revert
    function test_strategy_harvest_should_revert_during_partial_divest_if_pool_imbalanced()
        public
    {
        depositIntoVault(bob, 1E24);
        uint256 deposit = uint256(1E21);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        convexStrategy.runHarvest();
        uint256 initInvestment = convexPool.balanceOf(address(convexStrategy));

        gVault.setDebtRatio(address(convexStrategy), 7000);
        vm.stopPrank();
        uint256 calcAmount = (initInvestment * 7000) / 10000;
        manipulatePoolSmallerTokenAmount(false, 4500, frax_lp, address(frax));
        vm.startPrank(BASED_ADDRESS);
        (uint256 initExcessDebt, ) = gVault.excessDebt(address(convexStrategy));
        // Expect to revert because of excess debt
        vm.expectRevert(
            abi.encodeWithSelector(StrategyErrors.SlippageProtection.selector)
        );
        convexStrategy.runHarvest();
        (uint256 finalExcessDebt, ) = gVault.excessDebt(
            address(convexStrategy)
        );
        // Make sure convex strategy has the same amount of assets and excess debt after harvest failed
        assertApproxEqRel(
            convexPool.balanceOf(address(convexStrategy)),
            initInvestment,
            1E16
        );
        assertEq(initExcessDebt, finalExcessDebt);
        vm.stopPrank();
    }

    // Test case for potential MEV attack vector
    // Given a strategy with an investment in Convex and and excess debt
    // when the metapool is partly imbalanced (assets greater than excess debt) with a profit
    // then the harvest should go through and profit should be made
    function test_strategy_manipulation_during_divest_assets_from_convex_harvest_profit_large()
        public
    {
        depositIntoVault(bob, 1E24);
        uint256 deposit = uint256(1E21);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        convexStrategy.runHarvest();
        uint256 initInvestment = convexPool.balanceOf(address(convexStrategy));

        gVault.setDebtRatio(address(convexStrategy), 5000);
        uint256 calcAmount = (initInvestment * 5000) / 10000;
        vm.stopPrank();
        (
            uint256 poolTokens,
            uint256 investment
        ) = manipulatePoolSmallerTokenAmount(
                true,
                9000,
                frax_lp,
                address(THREE_POOL_TOKEN)
            );
        vm.startPrank(BASED_ADDRESS);
        (uint256 initExcessDebt, ) = gVault.excessDebt(address(convexStrategy));

        convexStrategy.runHarvest();

        vm.stopPrank();
        (uint256 finalTokens, ) = reverseManipulation(
            false,
            poolTokens,
            frax_lp,
            address(frax)
        );
        (uint256 finalExcessDebt, ) = gVault.excessDebt(
            address(convexStrategy)
        );
        // Make sure convex strategy has the expect amount of assets
        assertApproxEqRel(
            convexPool.balanceOf(address(convexStrategy)),
            calcAmount,
            1E16
        );
        // attacker has made a loss
        assertLt(finalTokens, investment);
        // debt has been repaid
        assertGt(initExcessDebt, finalExcessDebt);
    }

    // Test case for potential MEV attack vector
    // Given a strategy with an investment in Convex and and excess debt
    // when the metapool is partly imbalanced (assets greater than excess debt) with a profit
    // then the harvest should go through and profit should be made
    function test_strategy_manipulation_during_divest_assets_from_convex_harvest_profit_small()
        public
    {
        depositIntoVault(bob, 1E24);
        uint256 deposit = uint256(1E21);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        convexStrategy.runHarvest();
        uint256 initInvestment = convexPool.balanceOf(address(convexStrategy));

        gVault.setDebtRatio(address(convexStrategy), 5000);
        uint256 calcAmount = (initInvestment * 5000) / 10000;
        vm.stopPrank();
        (
            uint256 poolTokens,
            uint256 investment
        ) = manipulatePoolSmallerTokenAmount(
                true,
                50,
                frax_lp,
                address(THREE_POOL_TOKEN)
            );
        vm.startPrank(BASED_ADDRESS);
        (uint256 initExcessDebt, ) = gVault.excessDebt(address(convexStrategy));

        convexStrategy.runHarvest();
        vm.stopPrank();
        (uint256 finalTokens, ) = reverseManipulation(
            false,
            poolTokens,
            frax_lp,
            address(frax)
        );
        (uint256 finalExcessDebt, ) = gVault.excessDebt(
            address(convexStrategy)
        );
        // Make sure convex strategy has the expect amount of assets
        assertApproxEqRel(
            convexPool.balanceOf(address(convexStrategy)),
            calcAmount,
            1E16
        );
        // attacker has made a loss
        assertLt(finalTokens, investment);
        // debt has been repaid
        assertLt(finalExcessDebt, initExcessDebt);
    }

    // Test case for potential MEV attack vector
    // Given a strategy with an investment in Convex and and excess debt
    // when the metapool is partly imbalanced (assets greater than excess debt) with a profit
    // then the harvest should go through and profit should be made
    function test_strategy_harvest_should_revert_during_partial_divest_if_pool_imbalanced_profit_large()
        public
    {
        depositIntoVault(bob, 1E24);
        uint256 deposit = uint256(1E21);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        convexStrategy.runHarvest();
        uint256 initInvestment = convexPool.balanceOf(address(convexStrategy));

        gVault.setDebtRatio(address(convexStrategy), 7000);
        vm.stopPrank();
        uint256 calcAmount = (initInvestment * 7000) / 10000;
        (
            uint256 poolTokens,
            uint256 investment
        ) = manipulatePoolSmallerTokenAmount(
                true,
                9000,
                frax_lp,
                address(THREE_POOL_TOKEN)
            );
        vm.startPrank(BASED_ADDRESS);
        (uint256 initExcessDebt, ) = gVault.excessDebt(address(convexStrategy));

        convexStrategy.runHarvest();
        vm.stopPrank();
        (uint256 finalTokens, ) = reverseManipulation(
            false,
            poolTokens,
            frax_lp,
            address(frax)
        );
        (uint256 finalExcessDebt, ) = gVault.excessDebt(
            address(convexStrategy)
        );
        // Make sure convex strategy has the expect amount of assets
        assertApproxEqRel(
            convexPool.balanceOf(address(convexStrategy)),
            calcAmount,
            1E16
        );
        // attacker has made a loss
        assertLt(finalTokens, investment);
        assertLt(finalExcessDebt, initExcessDebt);
    }

    // Test case for potential MEV attack vector
    // Given a strategy with an investment in Convex and and excess debt
    // when the metapool is partly imbalanced (assets greater than excess debt)
    // then the harvest should revert
    function test_strategy_harvest_should_revert_during_partial_divest_if_pool_imbalanced_profit_small()
        public
    {
        depositIntoVault(bob, 1E24);
        uint256 deposit = uint256(1E21);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        convexStrategy.runHarvest();
        uint256 initInvestment = convexPool.balanceOf(address(convexStrategy));

        gVault.setDebtRatio(address(convexStrategy), 7000);
        vm.stopPrank();
        uint256 calcAmount = (initInvestment * 7000) / 10000;
        (
            uint256 poolTokens,
            uint256 investment
        ) = manipulatePoolSmallerTokenAmount(
                true,
                50,
                frax_lp,
                address(THREE_POOL_TOKEN)
            );
        vm.startPrank(BASED_ADDRESS);
        (uint256 initExcessDebt, ) = gVault.excessDebt(address(convexStrategy));

        convexStrategy.runHarvest();
        vm.stopPrank();
        (uint256 finalTokens, ) = reverseManipulation(
            false,
            poolTokens,
            frax_lp,
            address(frax)
        );
        (uint256 finalExcessDebt, ) = gVault.excessDebt(
            address(convexStrategy)
        );
        // Make sure convex strategy has the expect amount of assets
        assertApproxEqRel(
            convexPool.balanceOf(address(convexStrategy)),
            calcAmount,
            1E16
        );
        // attacker has made a loss
        assertLt(finalTokens, investment);
        assertLt(finalExcessDebt, initExcessDebt);
    }

    function test_strategy_manipulation_during_divest_assets_from_convex()
        public
    {
        depositIntoVault(bob, 1E24);
        uint256 deposit = uint256(1E21);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        convexStrategy.runHarvest();
        uint256 initInvestment = convexPool.balanceOf(address(convexStrategy));

        uint256 calc_amount = initInvestment - gVault.balanceOf(alice);
        vm.stopPrank();
        manipulatePoolSmallerTokenAmount(false, 9500, frax_lp, address(frax));
        vm.startPrank(alice);
        uint256 shares = gVault.redeem(
            gVault.balanceOf(alice),
            address(alice),
            address(alice)
        );
        assertApproxEqRel(
            convexPool.balanceOf(address(convexStrategy)),
            calc_amount,
            1E16
        );
        vm.stopPrank();
    }

    function test_strategy_can_divest_assets_from_convex(uint128 _deposit)
        public
    {
        uint256 deposit = uint256(_deposit);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E26) deposit = 1E26;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        IERC20 convexPool = IERC20(fraxConvexRewards);
        convexStrategy.runHarvest();
        uint256 initInvestment = convexPool.balanceOf(address(convexStrategy));

        gVault.setDebtRatio(address(convexStrategy), 5000);

        convexStrategy.runHarvest();
        assertApproxEqRel(
            convexPool.balanceOf(address(convexStrategy)),
            initInvestment / 2,
            1E16
        );
        vm.stopPrank();
    }

    // Given a strategy with more debt than assets
    // When the strategy is trying to migrate
    // Then the migration should revert
    function test_strategy_change_convex_pool_fails_when_loss() public {
        uint256 deposit = uint256(1E24);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E24) deposit = 1E24;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.setBaseSlippage(50);
        IERC20 convexPoolFrax = IERC20(fraxConvexRewards);
        IERC20 convexPoolMusd = IERC20(musdConvexRewards);
        convexStrategy.runHarvest();

        convexStrategy.setPool(musd_lp_pid, musd_curve);

        vm.stopPrank();
        manipulatePoolSmallerTokenAmount(false, 9999, frax_lp, address(frax));

        vm.startPrank(BASED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(StrategyErrors.LPNotZero.selector)
        );
        convexStrategy.runHarvest();

        vm.stopPrank();
    }

    function test_strategy_change_convex_pool(uint128 _deposit) public {
        uint256 deposit = uint256(_deposit);
        if (deposit < 1E20) deposit = 1E20;
        if (deposit > 1E24) deposit = 1E24;
        depositIntoVault(alice, deposit);
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.setBaseSlippage(50);
        IERC20 convexPoolFrax = IERC20(fraxConvexRewards);
        IERC20 convexPoolMusd = IERC20(musdConvexRewards);
        convexStrategy.runHarvest();
        assertGt(convexPoolFrax.balanceOf(address(convexStrategy)), 0);
        assertEq(convexPoolMusd.balanceOf(address(convexStrategy)), 0);

        uint256 currentPid;
        address currentMetaPool;
        address currentLptoken;
        uint256 plannedPid;
        address plannedMetaPool;
        address plannedLptoken;

        convexStrategy.setPool(musd_lp_pid, musd_curve);

        (currentPid, currentMetaPool, currentLptoken, ) = convexStrategy
            .getCurrentInvestment();
        (plannedPid, plannedMetaPool, plannedLptoken, ) = convexStrategy
            .getPlannedInvestment();

        assertEq(currentPid, frax_lp_pid);
        assertEq(currentMetaPool, frax_lp);
        assertEq(currentLptoken, frax_lp);

        assertEq(plannedPid, musd_lp_pid);
        assertEq(plannedMetaPool, musd_curve);
        assertEq(plannedLptoken, musd_lp);

        convexStrategy.runHarvest();

        (currentPid, currentMetaPool, currentLptoken, ) = convexStrategy
            .getCurrentInvestment();
        (plannedPid, plannedMetaPool, plannedLptoken, ) = convexStrategy
            .getPlannedInvestment();

        assertEq(currentPid, musd_lp_pid);
        assertEq(currentMetaPool, musd_curve);
        assertEq(currentLptoken, musd_lp);

        assertEq(plannedPid, 0);
        assertEq(plannedMetaPool, ZERO);
        assertEq(plannedLptoken, ZERO);

        assertEq(convexPoolFrax.balanceOf(address(convexStrategy)), 0);
        assertGt(convexPoolMusd.balanceOf(address(convexStrategy)), 0);

        vm.stopPrank();
    }

    function test_strategy_should_report_gains(uint128 _deposit, uint64 _profit)
        public
    {
        uint256 deposit = uint256(_deposit);
        uint256 profit = uint256(_profit);
        if (deposit < 1E24) deposit = 1E24;
        if (deposit > 1E28) deposit = 1E28;
        vm.assume(profit > 500);
        vm.assume(profit < 4000);

        uint256 shares = depositIntoVault(alice, deposit);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.setBaseSlippage(100);
        convexStrategy.runHarvest();
        vm.stopPrank();

        uint256 initEstimatedAssets = convexStrategy.estimatedTotalAssets();
        uint256 initVaultAssets = gVault.realizedTotalAssets();
        (, , , , uint256 initProfit, ) = gVault.strategies(
            address(convexStrategy)
        );
        manipulatePool(true, profit, frax_lp, address(THREE_POOL_TOKEN));

        assertLt(initEstimatedAssets, convexStrategy.estimatedTotalAssets());
        assertEq(initVaultAssets, gVault.realizedTotalAssets());

        uint256 estimatedProfit = convexStrategy.estimatedTotalAssets() -
            initEstimatedAssets;
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        vm.stopPrank();

        (, , , , uint256 finalProfit, ) = gVault.strategies(
            address(convexStrategy)
        );

        assertGt(finalProfit, initProfit);
        assertApproxEqRel(finalProfit, estimatedProfit, 5E17);
    }

    function test_strategy_should_report_loss(uint128 _deposit, uint128 _loss)
        public
    {
        uint256 deposit = uint256(_deposit);
        uint256 loss = uint256(_loss);
        if (deposit < 1E24) deposit = 1E24;
        if (deposit > 1E28) deposit = 1E28;
        vm.assume(loss > 500);
        vm.assume(loss < 4000);

        uint256 shares = depositIntoVault(alice, deposit);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.setBaseSlippage(100);
        convexStrategy.runHarvest();
        vm.stopPrank();

        uint256 initEstimatedAssets = convexStrategy.estimatedTotalAssets();
        uint256 initVaultAssets = gVault.realizedTotalAssets();
        (, , , , , uint256 initLoss) = gVault.strategies(
            address(convexStrategy)
        );

        manipulatePool(false, loss, frax_lp, frax);

        assertGt(initEstimatedAssets, convexStrategy.estimatedTotalAssets());
        assertEq(initVaultAssets, gVault.realizedTotalAssets());

        uint256 estimatedLoss = initEstimatedAssets -
            convexStrategy.estimatedTotalAssets();
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        vm.stopPrank();

        (, , , , , uint256 finalLoss) = gVault.strategies(
            address(convexStrategy)
        );

        assertGt(finalLoss, initLoss);
        assertApproxEqRel(finalLoss, estimatedLoss, 5E17);
    }

    function test_harvest_triggers_should_return_false_when() public {
        depositIntoVault(alice, 1E24);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        // < min report delay
        vm.warp(block.timestamp + MIN_REPORT_DELAY / 2);
        assertTrue(!convexStrategy.canHarvest());
        convexStrategy.runHarvest();
        // excess debt < debt_threshold
        vm.warp(block.timestamp + MIN_REPORT_DELAY);
        gVault.setDebtRatio(address(convexStrategy), 9999);
        assertTrue(!convexStrategy.canHarvest());
        convexStrategy.runHarvest();
        // profit < profit_threshold
        vm.warp(block.timestamp + MIN_REPORT_DELAY);
        setStorage(
            address(convexStrategy),
            THREE_POOL_TOKEN.balanceOf.selector,
            address(THREE_POOL_TOKEN),
            10_000 * 1E18
        );
        assertTrue(!convexStrategy.canHarvest());
        vm.stopPrank();
    }

    function test_should_return_all_assets_when_emergency() public {
        depositIntoVault(alice, 1E24);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();

        assertGt(convexStrategy.estimatedTotalAssets(), 0);
        assertEq(THREE_POOL_TOKEN.balanceOf(address(gVault)), 0);

        (bool initActive, , , uint256 initTotalDebt, , ) = gVault.strategies(
            address(convexStrategy)
        );
        assertGt(initTotalDebt, 0);
        assertTrue(!convexStrategy.emergencyMode());
        convexStrategy.setEmergencyMode();
        assertTrue(convexStrategy.emergencyMode());

        convexStrategy.runHarvest();

        (bool finalActive, , , uint256 finalTotalDebt, , ) = gVault.strategies(
            address(convexStrategy)
        );
        assertEq(convexStrategy.estimatedTotalAssets(), 0);
        assertEq(finalTotalDebt, 0);
        assertTrue(!finalActive);
        assertApproxEqRel(
            initTotalDebt,
            THREE_POOL_TOKEN.balanceOf(address(gVault)),
            1E16
        );
        vm.stopPrank();
        assertEq(
            THREE_POOL_TOKEN.balanceOf(address(gVault)),
            gVault.totalAssets()
        );
    }

    // TODO: This test is omitted
    function test_should_pull_out_all_asset_during_stop_loss() private {
        depositIntoVault(alice, 1E24);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        uint256 initStratAssets = convexStrategy.estimatedTotalAssets();
        assertGt(initStratAssets, 0);
        assertEq(THREE_POOL_TOKEN.balanceOf(address(convexStrategy)), 0);
        (bool initActive, , , uint256 initTotalDebt, , ) = gVault.strategies(
            address(convexStrategy)
        );
        assertGt(initTotalDebt, 0);
        assertTrue(!convexStrategy.stop());
        vm.stopPrank();

        manipulatePool(false, 500, frax_lp, frax);

        vm.startPrank(BASED_ADDRESS);
        while (true) {
            bool spl = convexStrategy.stopLoss();
            if (spl) break;
        }

        assertTrue(convexStrategy.stop());
        (bool finalActive, , , uint256 finalTotalDebt, , ) = gVault.strategies(
            address(convexStrategy)
        );
        uint256 finalStratAssets = convexStrategy.estimatedTotalAssets();
        assertGt(finalStratAssets, 0);
        assertApproxEqRel(initTotalDebt, finalTotalDebt, 5E16);
        assertTrue(finalActive);
        assertTrue(!convexStrategy.canHarvest());
        vm.stopPrank();
    }

    function test_should_increment_slipapge_on_stop_loss_failure() public {
        depositIntoVault(alice, 1E24);
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();

        vm.stopPrank();
        manipulatePool(false, 500, frax_lp, frax);

        vm.startPrank(BASED_ADDRESS);
        uint256 stopLossAttempts = convexStrategy.stopLossAttempts();
        uint256 i = 0;
        while (true) {
            assertEq(stopLossAttempts, i);
            bool check = convexStrategy.stopLoss();
            if (check) break;
            i++;
            stopLossAttempts = convexStrategy.stopLossAttempts();
        }
        assertTrue(convexStrategy.stop());
        assertEq(convexStrategy.stopLossAttempts(), 0);
        vm.stopPrank();
    }

    function test_should_reset_slippage_on_success() public {
        depositIntoVault(alice, 1E24);
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        vm.stopPrank();

        manipulatePool(false, 500, frax_lp, frax);

        vm.startPrank(BASED_ADDRESS);

        uint256 stopLossAttempts = convexStrategy.stopLossAttempts();
        uint256 i = 0;
        while (true) {
            assertEq(stopLossAttempts, i);
            bool check = convexStrategy.stopLoss();
            if (check) break;
            i++;
            stopLossAttempts = convexStrategy.stopLossAttempts();
        }
        assertTrue(convexStrategy.stop());
        assertEq(convexStrategy.stopLossAttempts(), 0);
        vm.stopPrank();
    }

    // TODO: This test is omitted
    function test_should_be_able_to_resume_strategy_after_stop_loss() private {
        depositIntoVault(alice, 1E24);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        uint256 initStratAssets = convexStrategy.estimatedTotalAssets();
        assertGt(initStratAssets, 0);
        assertEq(THREE_POOL_TOKEN.balanceOf(address(convexStrategy)), 0);
        (bool initActive, , , uint256 initTotalDebt, , ) = gVault.strategies(
            address(convexStrategy)
        );
        assertGt(initTotalDebt, 0);
        assertTrue(!convexStrategy.stop());
        vm.stopPrank();

        manipulatePool(false, 500, frax_lp, frax);
        vm.startPrank(BASED_ADDRESS);
        while (true) {
            bool spl = convexStrategy.stopLoss();
            if (spl) break;
        }

        assertTrue(convexStrategy.stop());
        (bool finalActive, , , uint256 finalTotalDebt, , ) = gVault.strategies(
            address(convexStrategy)
        );
        uint256 finalStratAssets = convexStrategy.estimatedTotalAssets();
        assertGt(finalStratAssets, 0);
        assertApproxEqRel(initTotalDebt, finalTotalDebt, 5E16);
        assertTrue(finalActive);
        assertTrue(!convexStrategy.canHarvest());

        vm.warp(block.timestamp + MAX_REPORT_DELAY + 1);
        assertTrue(!convexStrategy.canHarvest());
        convexStrategy.resume();
        assertTrue(convexStrategy.canHarvest());
        vm.stopPrank();
    }

    function test_harvest_triggers_should_return_true_when() public {
        depositIntoVault(alice, 1E24);
        vm.startPrank(BASED_ADDRESS);

        // set harvest > min report time
        vm.warp(block.timestamp + MIN_REPORT_DELAY);
        // excess debt > debt_threshold
        gVault.setDebtRatio(address(convexStrategy), 5000);
        assertTrue(convexStrategy.canHarvest());
        convexStrategy.runHarvest();
        assertTrue(!convexStrategy.canHarvest());

        vm.warp(block.timestamp + MAX_REPORT_DELAY);
        // > max report delay
        assertTrue(convexStrategy.canHarvest());
        convexStrategy.runHarvest();
        assertTrue(!convexStrategy.canHarvest());

        vm.warp(block.timestamp + MIN_REPORT_DELAY);
        // profit > profit_threshold
        setStorage(
            address(convexStrategy),
            THREE_POOL_TOKEN.balanceOf.selector,
            address(THREE_POOL_TOKEN),
            20_000 * 1E18 + 1E18
        );
        assertTrue(convexStrategy.canHarvest());
        convexStrategy.runHarvest();
        assertTrue(!convexStrategy.canHarvest());
        vm.stopPrank();
    }

    function test_strategy_should_generate_rewards() public {
        depositIntoVault(alice, 1E24);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        uint256 initialAssets = convexStrategy.estimatedTotalAssets();

        prepareRewards(fraxConvexRewards);
        assertGt(convexStrategy.estimatedTotalAssets(), initialAssets);
        vm.stopPrank();
    }

    function testClaimAndSweepRewards() public {
        depositIntoVault(alice, 1E24);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        uint256 initialAssets = convexStrategy.estimatedTotalAssets();

        prepareRewards(fraxConvexRewards);
        assertGt(convexStrategy.estimatedTotalAssets(), initialAssets);

        convexStrategy.claimRewards();
        // Check that balance of curve token is non 0 after claim:
        assertGt(CURVE_TOKEN.balanceOf(address(convexStrategy)), 0);
        assertEq(CURVE_TOKEN.balanceOf(address(this)), 0);
        // Sweep and check balance of curve token is 0 after sweep:
        convexStrategy.sweep(address(this), address(CURVE_TOKEN));
        assertEq(CURVE_TOKEN.balanceOf(address(convexStrategy)), 0);
        assertGt(CURVE_TOKEN.balanceOf(address(this)), 0);
        vm.stopPrank();
    }

    /// @notice Test for the case if crveth pool is borked and we can't sell rewards as usual
    /// Then we got to set CRV token as additional reward and sell it through that
    function testSellCrvAsAdditionalReward() public {
        depositIntoVault(alice, 1E24);
        tokens.push(address(CURVE_TOKEN));
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        uint256 initialAssets = convexStrategy.estimatedTotalAssets();

        prepareRewards(fraxConvexRewards);
        assertGt(convexStrategy.estimatedTotalAssets(), initialAssets);
        convexStrategy.setCrvEthPool(address(0));
        convexStrategy.setAdditionalRewards(tokens);
        // Harvest in normal mode should sell crv through additional rewards
        convexStrategy.runHarvest();
        // Check that rewards are sold
        assertEq(convexStrategy.rewards(), 0);
        assertEq(CURVE_TOKEN.balanceOf(address(convexStrategy)), 0);
        vm.stopPrank();
    }

    /// @notice Test for the case if crveth pool is borked and we can't sell rewards as usual
    /// Then we just set crveth pool as 0x and rewards should stay unsold
    function testSetCrvEthBorked() public {
        depositIntoVault(alice, 1E24);
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        uint256 initialAssets = convexStrategy.estimatedTotalAssets();

        prepareRewards(fraxConvexRewards);
        assertGt(convexStrategy.estimatedTotalAssets(), initialAssets);
        convexStrategy.setCrvEthPool(address(0));
        convexStrategy.runHarvest();
        // Check that rewards are claimed but crv is not sold
        assertEq(convexStrategy.rewards(), 0);
        assertGt(CURVE_TOKEN.balanceOf(address(convexStrategy)), 0);
        vm.stopPrank();
    }

    /// @notice Test for the case if crveth pool is borked and we set curve pool to a new one
    function testSetCrvEthBorkedNewPoolSet() public {
        depositIntoVault(alice, 1E24);
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        uint256 initialAssets = convexStrategy.estimatedTotalAssets();
        convexStrategy.setCrvEthPool(address(0));
        // Check that crv eth pool is now set to 0
        assertEq(convexStrategy.crvEthPool(), address(0));
        // Now set proper crveth pool and make sure rewards are sold
        convexStrategy.setCrvEthPool(CRV_ETH_POOL);
        prepareRewards(fraxConvexRewards);
        assertGt(convexStrategy.rewards(), 0);
        convexStrategy.runHarvest();
        assertEq(CURVE_TOKEN.balanceOf(address(convexStrategy)), 0);
        assertEq(convexStrategy.rewards(), 0);
        vm.stopPrank();
    }

    /// @notice Simple test to check allowance is set properly for additional rewards
    function testSetAdditionalTokensAllowanceCheck() public {
        // Make sure CRV starts with 0 allowance
        assertEq(
            CURVE_TOKEN.allowance(
                address(convexStrategy),
                address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
            ),
            0
        );
        tokens.push(address(CURVE_TOKEN));
        vm.startPrank(BASED_ADDRESS);
        convexStrategy.setAdditionalRewards(tokens);
        // Make sure Curve allowance for strategy is set as uint256 max value
        assertEq(
            CURVE_TOKEN.allowance(
                address(convexStrategy),
                address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
            ),
            type(uint256).max
        );
        // Now remove Curve from additional rewards and check that allowance is set to 0
        tokens.pop();
        tokens.push(address(USDC));
        convexStrategy.setAdditionalRewards(tokens);
        assertEq(
            CURVE_TOKEN.allowance(
                address(convexStrategy),
                address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
            ),
            0
        );
    }

    // TODO: This test is omitted
    function test_strategy_should_claim_and_sell_rewards() private {
        depositIntoVault(alice, 1E24);

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        uint256 initialAssets = convexStrategy.estimatedTotalAssets();
        (, , , uint256 initTotalDebt, , ) = gVault.strategies(
            address(convexStrategy)
        );

        prepareRewards(fraxConvexRewards);
        assertGt(convexStrategy.estimatedTotalAssets(), initialAssets);

        convexStrategy.runHarvest();

        (, , , uint256 finalTotalDebt, , ) = gVault.strategies(
            address(convexStrategy)
        );

        vm.stopPrank();
        assertGt(convexStrategy.estimatedTotalAssets(), initialAssets);
        assertGt(finalTotalDebt, initTotalDebt);
    }

    function testStrategySetAdditionalRewardsHappy() external {
        tokens.push(address(USDC));
        tokens.push(address(DAI));
        tokens.push(address(THREE_POOL_TOKEN));
        tokens.push(address(CURVE_TOKEN));
        vm.prank(BASED_ADDRESS);
        convexStrategy.setAdditionalRewards(tokens);

        // Make sure the tokens are added
        assertEq(convexStrategy.rewardTokens(0), address(USDC));
        assertEq(convexStrategy.rewardTokens(1), address(DAI));
        assertEq(convexStrategy.rewardTokens(2), address(THREE_POOL_TOKEN));
        assertEq(convexStrategy.rewardTokens(3), address(CURVE_TOKEN));
    }

    function testStrategySetAdditionalRewardsUnhappy() external {
        // Push invalid token address
        tokens.push(address(0));
        vm.startPrank(BASED_ADDRESS);
        vm.expectRevert();
        convexStrategy.setAdditionalRewards(tokens);
        vm.stopPrank();
    }

    function testStrategySetAdditionalRewardsUnhappyRewardsTokenMax() external {
        // Push more than MAX_REWARDS tokens:
        for (uint256 i = 0; i < 10; i++) {
            tokens.push(address(USDC));
        }
        vm.startPrank(BASED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(StrategyErrors.RewardsTokenMax.selector)
        );
        convexStrategy.setAdditionalRewards(tokens);
        vm.stopPrank();
    }
}
