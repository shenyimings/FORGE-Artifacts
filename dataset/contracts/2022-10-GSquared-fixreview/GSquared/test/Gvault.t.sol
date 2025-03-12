// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.GSquared.t.sol";
import "../contracts/utils/StrategyQueue.sol";

contract GVaultTest is Test, BaseSetup {
    using stdStorage for StdStorage;

    function testDepositWithdraws() public {
        genThreeCrv(uint256(1E25), alice);
        vm.startPrank(alice);

        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);
        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);

        gVault.deposit(100E18, alice);

        assertLt(THREE_POOL_TOKEN.balanceOf(alice), alice3CrvBalance);
        assertGt(gVault.balanceOf(alice), 0);

        alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);
        gVault.deposit(50E18, alice);

        assertLt(THREE_POOL_TOKEN.balanceOf(alice), alice3CrvBalance);
        assertGt(gVault.balanceOf(alice), 0);

        gVault.approve(address(gVault), MAX_UINT);

        alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);
        uint256 alicegVaultBalance = gVault.balanceOf(alice);
        gVault.withdraw(10E18, alice, alice);

        assertGt(THREE_POOL_TOKEN.balanceOf(alice), alice3CrvBalance);
        assertLt(gVault.balanceOf(alice), alicegVaultBalance);

        alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);
        gVault.withdraw(10E16, alice, alice);

        assertGt(THREE_POOL_TOKEN.balanceOf(alice), alice3CrvBalance);
        assertLt(gVault.balanceOf(alice), alicegVaultBalance);

        vm.stopPrank();
    }

    function addStrategies() public returns (address[4] memory strategies) {
        vm.startPrank(BASED_ADDRESS);

        strategy = new MockStrategy(address(gVault));
        gVault.addStrategy(address(strategy), 0);
        strategies[0] = address(strategy);

        strategy = new MockStrategy(address(gVault));
        gVault.addStrategy(address(strategy), 0);
        strategies[1] = address(strategy);

        strategy = new MockStrategy(address(gVault));
        gVault.addStrategy(address(strategy), 0);
        strategies[2] = address(strategy);

        strategy = new MockStrategy(address(gVault));
        gVault.addStrategy(address(strategy), 0);
        strategies[3] = address(strategy);
        vm.stopPrank();
    }

    function testDeposits() public {
        genThreeCrv(uint256(1E25), alice);
        genThreeCrv(uint256(1E25), bob);

        vm.startPrank(alice);

        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);
        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);

        gVault.deposit(uint256(100E18), alice);

        assertLt(THREE_POOL_TOKEN.balanceOf(alice), alice3CrvBalance);
        assertGt(gVault.balanceOf(alice), 0);

        vm.stopPrank();

        vm.startPrank(bob);

        uint256 bob3CrvBalance = THREE_POOL_TOKEN.balanceOf(bob);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.deposit(uint256(100E18), bob);

        assertLt(THREE_POOL_TOKEN.balanceOf(bob), bob3CrvBalance);
        assertGt(gVault.balanceOf(bob), 0);

        vm.stopPrank();
    }

    function testDepositZeroShare() public {
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.MinDeposit.selector));
        gVault.deposit(0, alice);
        vm.stopPrank();
    }

    function testMint() public {
        genThreeCrv(uint256(1E25), alice);
        genThreeCrv(uint256(1E25), bob);

        vm.startPrank(alice);

        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(uint256(100E18), alice);

        assertLt(THREE_POOL_TOKEN.balanceOf(alice), alice3CrvBalance);
        assertGt(gVault.balanceOf(alice), 0);

        vm.stopPrank();

        vm.startPrank(bob);

        uint256 bob3CrvBalance = THREE_POOL_TOKEN.balanceOf(bob);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(uint256(100E18), bob);

        assertLt(THREE_POOL_TOKEN.balanceOf(bob), bob3CrvBalance);
        assertGt(gVault.balanceOf(bob), 0);

        vm.stopPrank();
    }

    function testMintZeroShare() public {
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        vm.expectRevert(abi.encodeWithSelector(Errors.MinDeposit.selector));
        gVault.mint(0, alice);
        vm.stopPrank();
    }

    function testWithdrawZeroShare() public {
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E20, alice);

        assertGt(gVault.balanceOf(alice), 0);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAssets.selector));
        gVault.withdraw(0, alice, alice);
        vm.stopPrank();
    }

    function testiWithdrawToMuch() public {
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E20, alice);

        assertGt(gVault.balanceOf(alice), 0);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InsufficientShares.selector)
        );
        gVault.withdraw(1E25, alice, alice);
        vm.stopPrank();
    }

    function testRedeemZero() public {
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E20, alice);

        assertGt(gVault.balanceOf(alice), 0);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroShares.selector));
        gVault.redeem(0, alice, alice);
        vm.stopPrank();
    }

    function testRedeemToMuch() public {
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E20, alice);

        assertGt(gVault.balanceOf(alice), 0);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InsufficientShares.selector)
        );
        gVault.redeem(1E25, alice, alice);
        vm.stopPrank();
    }

    function testMaxDeposit() public {
        assertEq(gVault.maxDeposit(alice), type(uint256).max);
    }

    function testMaxMint() public {
        assertEq(gVault.maxMint(alice), type(uint256).max);
    }

    function testMaxRedeem() public {
        assertEq(gVault.maxRedeem(alice), 0);
        genThreeCrv(uint256(1E25), alice);
        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.deposit(1E20, alice);
        assertEq(gVault.maxRedeem(alice), 1E20);
        vm.stopPrank();
    }

    function testMaxWithdrawal() public {
        assertEq(gVault.maxWithdraw(alice), 0);
        genThreeCrv(uint256(1E25), alice);
        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.deposit(1E20, alice);
        assertEq(gVault.maxWithdraw(alice), 1E20);
        vm.stopPrank();
    }

    function testPreviewDeposit() public {
        assertEq(gVault.previewDeposit(100E18), 100E18);
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E20, alice);
        assertEq(gVault.previewDeposit(100E18), 100E18);
        vm.stopPrank();
    }

    function testPreviewMint() public {
        assertEq(gVault.previewMint(100E18), 100E18);
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E20, alice);
        assertEq(gVault.previewMint(100E18), 100E18);
        vm.stopPrank();
    }

    function testPreviewWithdrawal() public {
        assertEq(gVault.previewWithdraw(100E18), 100E18);
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E20, alice);
        assertEq(gVault.previewWithdraw(100E18), 100E18);
        gVault.withdraw(10E18, alice, alice);
        assertEq(gVault.previewWithdraw(100E18), 100E18);
        vm.stopPrank();
    }

    function testPreviewRedeem() public {
        assertEq(gVault.previewRedeem(100E18), 100E18);
        genThreeCrv(uint256(1E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E20, alice);
        assertEq(gVault.previewRedeem(100E18), 100E18);
        gVault.redeem(10E18, alice, alice);
        assertEq(gVault.previewRedeem(100E18), 100E18);
        vm.stopPrank();
    }

    function testTotalAssets(uint256 amount, bool gain) public {
        vm.assume(amount > 1E20);
        vm.assume(amount < 1E25);

        genThreeCrv(uint256(2E25), alice);

        vm.startPrank(alice);
        uint256 alice3CrvBalance = THREE_POOL_TOKEN.balanceOf(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E25, alice);
        vm.stopPrank();
        assertEq(gVault.totalAssets(), 1E25);
        assertEq(
            (gVault.totalAssets() * 1E18) / gVault.totalSupply(),
            gVault.getPricePerShare()
        );

        vm.startPrank(BASED_ADDRESS);
        strategy.runHarvest();
        amount = gain ? amount * 2 : amount / 2;
        setStorage(
            address(strategy),
            THREE_POOL_TOKEN.balanceOf.selector,
            address(THREE_POOL_TOKEN),
            amount
        );
        strategy.runHarvest();
        vm.warp(block.timestamp + gVault.releaseTime());
        vm.stopPrank();

        assertEq(gVault.totalAssets(), amount);
        assertEq(
            (gVault.totalAssets() * 1E18) / gVault.totalSupply(),
            gVault.getPricePerShare()
        );
    }

    function testConvertToShare() public {
        assertEq(gVault.convertToShares(1E18), 1E18);

        genThreeCrv(uint256(2E25), alice);
        vm.startPrank(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E25, alice);
        assertEq(gVault.convertToShares(1E18), 1E18);

        THREE_POOL_TOKEN.transfer(address(strategy), 1E25);
        vm.stopPrank();
        vm.startPrank(BASED_ADDRESS);
        strategy.runHarvest();
        vm.warp(block.timestamp + 10000);
        assertLt(gVault.convertToShares(1E18), 1E18);
        vm.stopPrank();
    }

    function testConvertToAssets() public {
        assertEq(gVault.convertToAssets(1E18), 1E18);

        genThreeCrv(uint256(2E25), alice);
        vm.startPrank(alice);

        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.mint(1E25, alice);
        assertEq(gVault.convertToAssets(1E18), 1E18);

        THREE_POOL_TOKEN.transfer(address(strategy), 1E25);
        vm.stopPrank();
        vm.startPrank(BASED_ADDRESS);
        strategy.runHarvest();
        vm.warp(block.timestamp + 10000);
        assertGt(gVault.convertToAssets(1E18), 1E18);
        vm.stopPrank();
    }

    function testStrategyLength() public {
        assertEq(gVault.getNoOfStrategies(), 1);
        addStrategies();
        assertEq(gVault.getNoOfStrategies(), 5);
    }

    function testSetDebtRatio() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes("UNAUTHORIZED"));
        gVault.setDebtRatio(address(strategy), 0);
        vm.stopPrank();

        vm.startPrank(BASED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.StrategyNotActive.selector)
        );
        gVault.setDebtRatio(ZERO, 0);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.VaultDebtRatioTooHigh.selector)
        );
        gVault.setDebtRatio(address(strategy), 11000);

        uint256 debt;
        (, debt, , , , ) = gVault.strategies(address(strategy));
        assertEq(debt, 10000);

        gVault.setDebtRatio(address(strategy), 4000);
        (, debt, , , , ) = gVault.strategies(address(strategy));
        assertEq(debt, 4000);
        vm.stopPrank();
    }

    function testMaxStrategies() public {
        assertEq(gVault.getNoOfStrategies(), 1);
        addStrategies();
        assertEq(gVault.getNoOfStrategies(), 5);

        vm.startPrank(BASED_ADDRESS);
        strategy = new MockStrategy(address(gVault));
        vm.expectRevert(
            abi.encodeWithSelector(StrategyQueue.MaxStrategyExceeded.selector)
        );
        gVault.addStrategy(address(strategy), 0);
        assertEq(gVault.getNoOfStrategies(), 5);
        vm.stopPrank();
    }

    function testAddStrategy() public {
        vm.startPrank(BASED_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        gVault.addStrategy(ZERO, 0);

        MockStrategy strategyNew = new MockStrategy(address(gVault));

        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyActive.selector));
        gVault.addStrategy(address(strategy), 0);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.VaultDebtRatioTooHigh.selector)
        );
        gVault.addStrategy(address(strategyNew), 1000);

        GVault gVaultNew = new GVault(THREE_POOL_TOKEN);
        strategy = new MockStrategy(address(gVaultNew));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.IncorrectVaultOnStrategy.selector)
        );
        gVault.addStrategy(address(strategy), 1000);

        gVault.addStrategy(address(strategyNew), 0);

        assertEq(gVault.withdrawalQueueAt(1), address(strategyNew));
        vm.stopPrank();
    }

    function testRemoevStrategy() public {
        vm.startPrank(BASED_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        gVault.addStrategy(ZERO, 0);

        MockStrategy strategyNew = new MockStrategy(address(gVault));

        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyActive.selector));
        gVault.addStrategy(address(strategy), 0);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.VaultDebtRatioTooHigh.selector)
        );
        gVault.addStrategy(address(strategyNew), 1000);

        GVault gVaultNew = new GVault(THREE_POOL_TOKEN);
        strategy = new MockStrategy(address(gVaultNew));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.IncorrectVaultOnStrategy.selector)
        );
        gVault.addStrategy(address(strategy), 1000);

        gVault.addStrategy(address(strategyNew), 0);

        assertEq(gVault.withdrawalQueueAt(1), address(strategyNew));
        vm.stopPrank();
    }

    function testRemoveStrategy() public {
        vm.startPrank(BASED_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        gVault.addStrategy(ZERO, 0);

        MockStrategy strategyNew = new MockStrategy(address(gVault));

        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyActive.selector));
        gVault.addStrategy(address(strategy), 0);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.VaultDebtRatioTooHigh.selector)
        );
        gVault.addStrategy(address(strategyNew), 1000);

        GVault gVaultNew = new GVault(THREE_POOL_TOKEN);
        strategy = new MockStrategy(address(gVaultNew));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.IncorrectVaultOnStrategy.selector)
        );
        gVault.addStrategy(address(strategy), 1000);

        gVault.addStrategy(address(strategyNew), 0);

        assertEq(gVault.withdrawalQueueAt(1), address(strategyNew));
        vm.stopPrank();
    }

    function test_credit_available() public {
        // take snapshot to be able to test both func signatures of credit available
        // check current credit
        uint256 creditAvailable = gVault.creditAvailable(address(strategy));
        assertEq(creditAvailable, 0);

        // check the same as above but with diff func signature that is called from strategy
        vm.startPrank(address(strategy));
        creditAvailable = gVault.creditAvailable(address(strategy));
        assertEq(creditAvailable, 0);
        vm.stopPrank();

        // transfer funds to mock funds available for strategy
        genThreeCrv(1E25, alice);
        vm.startPrank(alice);
        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        gVault.deposit(1E23, alice);
        // check credit available has changed with a debt ratio of 50% for strategy
        creditAvailable = gVault.creditAvailable(address(strategy));
        assertEq(creditAvailable, 1E23);
        vm.stopPrank();

        // check the same as above but with diff func signature that is called from strategy
        vm.startPrank(address(strategy));
        creditAvailable = gVault.creditAvailable(address(strategy));
        assertEq(creditAvailable, 1E23);
        vm.stopPrank();
    }

    function test_strategy_debt(uint128 _amount) public {
        if (_amount > 1E26) _amount = 1E26;
        if (_amount < 1E21) _amount = 1E21;
        uint256 amount = uint256(_amount);
        // test if a strategy shows the correct debt outstanding
        uint256 debtOutstanding;
        uint256 debtRatio;

        // fund vault then runHarvest to have funds sent to strategy
        uint256 shares = depositIntoVault(address(alice), amount);
        genThreeCrv(1E25, alice);

        vm.startPrank(BASED_ADDRESS);
        strategy.runHarvest();
        vm.stopPrank();
        (debtOutstanding, debtRatio) = gVault.excessDebt(address(strategy));
        assertEq(debtOutstanding, 0);

        vm.startPrank(alice);
        THREE_POOL_TOKEN.transfer(address(strategy), 1E23);
        vm.stopPrank();

        // reduce the debt ratio of the strategy so it owes money to the vault
        vm.startPrank(BASED_ADDRESS);
        gVault.setDebtRatio(address(strategy), 5000);
        vm.stopPrank();
        // check for the correct debt outstanding
        (, , , uint256 totalDebt, , ) = gVault.strategies(address(strategy));
        (debtOutstanding, debtRatio) = gVault.excessDebt(address(strategy));
        assertApproxEqRel((debtOutstanding * 10000) / totalDebt, 5000, 1E16);
    }

    function test_report_to_much_loss(uint128 _amount) public {
        if (_amount > 1E26) _amount = 1E26;
        if (_amount < 1E21) _amount = 1E21;
        uint256 amount = uint256(_amount);
        // the current version of the
        //   strategy uses estimated total assets for its report
        // Should not be possible for a strategy
        // to report a higher gain than actually available to the vault
        // with brownie.reverts(error_string("IncorrectStrategyAccounting()")):
        //     primary_mock_strategy.setTooMuchGain()
        //     mock_usdc.transfer(primary_mock_strategy.address, 10000 * 1e6, {"from": bob})
        //     primary_mock_strategy.runHarvest()
        // chain.revert()
        // Should not be possible for a strategy
        // to report a higher loss than actually possible to the vault
        uint256 shares = depositIntoVault(address(alice), amount);

        vm.startPrank(BASED_ADDRESS);
        strategy.runHarvest();
        strategy.setTooMuchLoss();
        strategy._takeFunds(shares);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.StrategyLossTooHigh.selector)
        );
        strategy.runHarvest();
    }

    function test_report_loss(uint128 _amount) public {
        if (_amount > 1E26) _amount = 1E26;
        if (_amount < 1E21) _amount = 1E21;
        uint256 amount = uint256(_amount);
        uint256 shares = depositIntoVault(address(alice), amount);

        vm.startPrank(BASED_ADDRESS);

        // PPS should decrease after a loss
        // to check loss reported correctly
        assertEq(gVault.getPricePerShare(), 1e18);
        strategy.runHarvest();
        (, , , uint256 initDebt, uint256 initProfit, uint256 initLoss) = gVault
            .strategies(address(strategy));
        strategy._takeFunds(shares / 2);
        strategy.runHarvest();
        (
            ,
            ,
            ,
            uint256 finalDebt,
            uint256 finalProfit,
            uint256 finalLoss
        ) = gVault.strategies(address(strategy));
        assertLt(gVault.getPricePerShare(), 1e18);
        assertLt(finalDebt, initDebt);
        assertGt(finalLoss, initLoss);
        assertEq(finalProfit, initProfit);
    }

    function test_report_gain(uint128 _amount) public {
        if (_amount > 1E26) _amount = 1E26;
        if (_amount < 1E21) _amount = 1E21;
        uint256 amount = uint256(_amount);
        uint256 shares = depositIntoVault(address(alice), amount);

        vm.startPrank(BASED_ADDRESS);

        // PPS should decrease after a loss
        // to check loss reported correctly
        assertEq(gVault.getPricePerShare(), 1e18);
        strategy.runHarvest();
        vm.stopPrank();

        genThreeCrv(uint256(1E25), alice);
        (, , , uint256 initDebt, uint256 initProfit, uint256 initLoss) = gVault
            .strategies(address(strategy));
        vm.startPrank(alice);
        THREE_POOL_TOKEN.transfer(address(strategy), 1E24);
        vm.stopPrank();

        vm.startPrank(BASED_ADDRESS);
        strategy.runHarvest();
        (
            ,
            ,
            ,
            uint256 finalDebt,
            uint256 finalProfit,
            uint256 finalLoss
        ) = gVault.strategies(address(strategy));
        vm.stopPrank();
        vm.warp(block.timestamp + 10000);
        assertGt(gVault.getPricePerShare(), 1e18);
        assertGt(finalDebt, initDebt);
        assertEq(finalLoss, initLoss);
        assertGt(finalProfit, initProfit);
    }

    // OTHERS TEST

    // Test queue

    // Given a vault zero or more strategies
    // When a new strategy is added
    // Then it should be the last item in the queue
    function test_new_strategy_should_be_added_to_end() public {
        assertEq(gVault.withdrawalQueueAt(1), ZERO);
        vm.startPrank(BASED_ADDRESS);

        MockStrategy strategy_2 = new MockStrategy(address(gVault));
        gVault.addStrategy(address(strategy_2), 0);

        assertEq(gVault.withdrawalQueueAt(1), address(strategy_2));
        assertEq(gVault.withdrawalQueueAt(2), ZERO);

        MockStrategy strategy_3 = new MockStrategy(address(gVault));
        gVault.addStrategy(address(strategy_3), 0);

        assertEq(gVault.withdrawalQueueAt(1), address(strategy_2));
        assertEq(gVault.withdrawalQueueAt(2), address(strategy_3));
        assertEq(gVault.withdrawalQueueAt(3), ZERO);
    }

    // Given a vault with one or more strategies
    // When a strategy removed
    // Then the queue order should be updated
    function test_removing_a_strategy_should_update_the_queue_order() public {
        vm.startPrank(BASED_ADDRESS);
        gVault.removeStrategy(address(strategy));
        vm.stopPrank();

        address[4] memory strategies = addStrategies();

        for (uint256 i; i < 4; i++) {
            assertEq(gVault.getStrategyPositions(strategies[i]), i);
        }
        vm.startPrank(BASED_ADDRESS);
        gVault.removeStrategy(strategies[0]);
        vm.stopPrank();

        for (uint256 i = 1; i < 4; i++) {
            assertEq(gVault.getStrategyPositions(strategies[i]), i - 1);
        }
    }

    // Given a vault with zero or more strategies
    // When a strategy is added
    // Then the id of the new strategy is unique
    function test_strategy_should_have_a_unique_id_when_added() public {
        vm.startPrank(BASED_ADDRESS);
        uint256 removedId = gVault.getStrategyPositions(address(strategy));
        gVault.removeStrategy(address(strategy));
        vm.stopPrank();

        address[4] memory strategies = addStrategies();

        vm.startPrank(BASED_ADDRESS);
        MockStrategy strategyNew = new MockStrategy(address(gVault));
        gVault.addStrategy(address(strategyNew), 0);
        vm.stopPrank();
        uint256 newStrategyId = gVault.getStrategyPositions(
            address(strategyNew)
        );
        assertTrue(newStrategyId != removedId);

        for (uint256 i = 0; i < 4; i++) {
            assertTrue(
                newStrategyId != gVault.getStrategyPositions(strategies[i])
            );
        }
    }

    // Given a vault with one or more strategies
    // When a new strategy is moved
    // Then the strategy should end up in the desired position
    function test_it_should_be_possible_to_move_strategy() public {
        vm.startPrank(BASED_ADDRESS);
        gVault.removeStrategy(address(strategy));
        vm.stopPrank();

        address[4] memory strategies = addStrategies();

        vm.startPrank(BASED_ADDRESS);

        assertEq(gVault.getStrategyPositions(strategies[3]), 3);
        gVault.moveStrategy(strategies[3], 1);

        assertEq(gVault.getStrategyPositions(strategies[3]), 1);
        gVault.moveStrategy(strategies[3], 2);

        assertEq(gVault.getStrategyPositions(strategies[3]), 2);
        vm.stopPrank();
    }

    // Given a vault with one or more strategies
    // When a strategy is moved to the same position
    // Then it should remain there
    function test_it_should_not_move_the_strategy_if_same_pos_specified()
        public
    {
        vm.startPrank(BASED_ADDRESS);
        gVault.removeStrategy(address(strategy));
        vm.stopPrank();

        address[4] memory strategies = addStrategies();

        vm.startPrank(BASED_ADDRESS);
        assertEq(gVault.getStrategyPositions(strategies[3]), 3);
        assertEq(gVault.getStrategyPositions(strategies[2]), 2);
        assertEq(gVault.getStrategyPositions(strategies[1]), 1);
        assertEq(gVault.getStrategyPositions(strategies[0]), 0);
        vm.expectRevert(
            abi.encodeWithSelector(StrategyQueue.StrategyNotMoved.selector, 1)
        );
        gVault.moveStrategy(strategies[2], 2);
        assertEq(gVault.getStrategyPositions(strategies[3]), 3);
        assertEq(gVault.getStrategyPositions(strategies[2]), 2);
        assertEq(gVault.getStrategyPositions(strategies[1]), 1);
        assertEq(gVault.getStrategyPositions(strategies[0]), 0);
        vm.stopPrank();
    }

    // Given a vault with one or more strategies
    // When a strategy is moved backwards in the queue
    // Then it should not be possible to move the strategy beyond the tail position
    function test_it_should_not_be_possible_to_move_tail_further_back() public {
        vm.startPrank(BASED_ADDRESS);
        gVault.removeStrategy(address(strategy));
        vm.stopPrank();
        address[4] memory strategies = addStrategies();
        vm.startPrank(BASED_ADDRESS);
        assertEq(gVault.getStrategyPositions(strategies[3]), 3);
        assertEq(gVault.getStrategyPositions(strategies[2]), 2);
        assertEq(gVault.getStrategyPositions(strategies[1]), 1);
        assertEq(gVault.getStrategyPositions(strategies[0]), 0);
        gVault.moveStrategy(strategies[1], 100);
        assertEq(gVault.getStrategyPositions(strategies[3]), 2);
        assertEq(gVault.getStrategyPositions(strategies[2]), 1);
        assertEq(gVault.getStrategyPositions(strategies[1]), 3);
        assertEq(gVault.getStrategyPositions(strategies[0]), 0);
        vm.stopPrank();
    }
}
