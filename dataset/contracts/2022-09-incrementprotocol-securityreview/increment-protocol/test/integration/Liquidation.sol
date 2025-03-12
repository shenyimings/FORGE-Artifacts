// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";

// interfaces
import "../../contracts/interfaces/IClearingHouse.sol";

// libraries
import "../../contracts/lib/LibMath.sol";
import "../../contracts/lib/LibPerpetual.sol";

contract Liquidation is Deployment {
    // events
    event LiquidationCall(
        uint256 indexed idx,
        address indexed liquidatee,
        address indexed liquidator,
        uint256 notional,
        int256 profit,
        int256 tradingFeesPayed,
        bool isTrader
    );
    event SeizeCollateral(address indexed liquidatee, address indexed liquidator);
    event TraderBadDebtGenerated(address beneficiary, uint256 amount);

    // libraries
    using LibMath for uint256;
    using LibMath for int256;

    // addresses
    address lp = address(123);
    address alice = address(456);
    address bob = address(789);

    // config values
    uint256 maxTradeAmount;
    uint256 minTradeAmount;
    uint256 liquidityMultiplier = 10; // Liquidity provided should be 10x the trade amount
    uint24 usdcHeartBeat = 25 hours;

    function _dealUaAndDeposit(address addr, uint256 amount) internal {
        deal(address(ua), addr, amount);

        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        clearingHouse.deposit(amount, ua);
        vm.stopPrank();
    }

    function _dealUsdcAndDeposit(address addr, uint256 amount) internal {
        bool isWhitelisted = vault.tokenToCollateralIdx(usdc) != 0;

        if (!isWhitelisted) {
            vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
            oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        }

        deal(address(usdc), addr, amount);
        vm.startPrank(addr);
        usdc.approve(address(vault), amount);
        clearingHouse.deposit(amount, usdc);
        vm.stopPrank();
    }

    function _fundLiquidityPool(uint256 idx, uint256 tradeAmount) internal {
        IPerpetual perp = clearingHouse.perpetuals(idx);
        uint256 liquidityAmount = tradeAmount * liquidityMultiplier;
        _dealUaAndDeposit(lp, liquidityAmount);

        uint256 quoteAmount = liquidityAmount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(perp.indexPrice().toUint256());

        vm.startPrank(lp);
        clearingHouse.provideLiquidity(idx, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function _setTraderBelowMargin(address liquidatee, int256 targetMargin) internal {
        int256 pnl = clearingHouse.getPnLAcrossMarkets(liquidatee);
        int256 reserveValue = vault.getReserveValue(liquidatee, false);
        int256 marginRequired = clearingHouse.getTotalMarginRequirement(liquidatee, targetMargin);

        int256 freeCollateral = reserveValue.min(reserveValue + pnl) - marginRequired;

        // remove free collateral + 1
        vault.__TestVault__changeTraderBalance(liquidatee, 0, -(freeCollateral + 1));
        assertLt(viewer.marginRatio(liquidatee), targetMargin);
    }

    function setUp() public virtual override {
        super.setUp();
        maxTradeAmount = perpetual.maxPosition();
        minTradeAmount = clearingHouse.minPositiveOpenNotional();
    }

    function test_FailsToLiquidateTraderWithoutPosition() public {
        vm.expectRevert(IClearingHouse.ClearingHouse_LiquidateInvalidPosition.selector);
        clearingHouse.liquidateTrader(0, alice, 0, 0);
    }

    function test_FailsToLiquidateTraderWithValidPosition() public {
        _fundLiquidityPool(0, minTradeAmount);

        vm.expectRevert(IClearingHouse.ClearingHouse_LiquidateInvalidPosition.selector);
        clearingHouse.liquidateTrader(0, lp, 0, 0);
    }

    function testFuzz_FailsToLiquidateTraderWithEnoughMargin(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);
        _dealUaAndDeposit(alice, tradeAmount.wadDiv(clearingHouse.minMarginAtCreation().toUint256()));

        vm.startPrank(alice);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        vm.expectRevert(IClearingHouse.ClearingHouse_LiquidateValidMargin.selector);
        clearingHouse.liquidateTrader(0, alice, 0, 0);
    }

    function testFuzz_LiquidateLongTraderWithInsufficientMargin(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);
        _dealUaAndDeposit(alice, tradeAmount.wadDiv(clearingHouse.minMarginAtCreation().toUint256()));

        vm.startPrank(alice);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        int256 aliceVaultBeforeClosing = vault.getReserveValue(alice, false);
        int256 bobVaultBeforeLiquidation = vault.getReserveValue(bob, false);
        uint256 insuranceBalanceBeforeLiquidation = ua.balanceOf(address(insurance));

        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        LibPerpetual.TraderPosition memory alicePositionBefore = perpetual.getTraderPosition(alice);

        vm.expectEmit(true, true, true, false);
        emit LiquidationCall(0, alice, bob, int256(alicePositionBefore.openNotional).abs().toUint256(), 0, 0, true);
        vm.startPrank(bob);
        clearingHouse.liquidateTrader(0, alice, int256(alicePositionBefore.positionSize).toUint256(), 0);
        vm.stopPrank();

        LibPerpetual.TraderPosition memory alicePositionAfter = perpetual.getTraderPosition(alice);

        assertEq(alicePositionAfter.openNotional, 0);
        assertEq(alicePositionAfter.positionSize, 0);

        int256 aliceVaultBalanceAfterClosing = vault.getReserveValue(alice, false);
        assertLt(aliceVaultBalanceAfterClosing, aliceVaultBeforeClosing);

        uint256 liquidationRewardAmount = tradeAmount.wadMul(clearingHouse.liquidationReward());
        uint256 liquidationRewardInsuranceShare = clearingHouse.liquidationRewardInsuranceShare();
        uint256 liquidatorLiquidationReward = liquidationRewardAmount.wadMul(1 ether - liquidationRewardInsuranceShare);
        uint256 insuranceLiquidationReward = liquidationRewardAmount - liquidatorLiquidationReward;

        int256 bobVaultBalanceAfterLiquidation = vault.getReserveValue(bob, false);
        assertApproxEqAbs(
            bobVaultBalanceAfterLiquidation, bobVaultBeforeLiquidation + liquidatorLiquidationReward.toInt256(), 1
        );

        uint256 insuranceBalanceAfterLiquidation = ua.balanceOf(address(insurance));
        assertApproxEqAbs(
            insuranceBalanceAfterLiquidation.toInt256(),
            insuranceBalanceBeforeLiquidation.toInt256() + insuranceLiquidationReward.toInt256(),
            1
        );
    }

    function testFuzz_FailsToLiquidateWithInsufficientProposedAmountLong(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);
        _dealUaAndDeposit(alice, tradeAmount.wadDiv(clearingHouse.minMarginAtCreation().toUint256()));

        vm.startPrank(alice);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        int256 positionSize = perpetual.getTraderPosition(alice).positionSize;
        int256 proposedAmount = positionSize - positionSize / 10;

        vm.expectRevert(IClearingHouse.ClearingHouse_LiquidateInsufficientProposedAmount.selector);
        vm.startPrank(bob);
        clearingHouse.liquidateTrader(0, alice, proposedAmount.toUint256(), 0);
        vm.stopPrank();
    }

    function testFuzz_FailsToLiquidateWithInsufficientProposedAmountShort(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);
        _dealUaAndDeposit(alice, tradeAmount.wadDiv(clearingHouse.minMarginAtCreation().toUint256()));

        tradeAmount = tradeAmount.wadDiv(perpetual.indexPrice().toUint256());

        vm.startPrank(alice);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        uint256 proposedAmount = int256(perpetual.getTraderPosition(alice).openNotional).toUint256() / 10;

        vm.expectRevert(IClearingHouse.ClearingHouse_LiquidateInsufficientProposedAmount.selector);
        vm.startPrank(bob);
        clearingHouse.liquidateTrader(0, alice, proposedAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_LiquidateShortPositionWithInsufficientMargin(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);
        _dealUaAndDeposit(alice, tradeAmount.wadDiv(clearingHouse.minMarginAtCreation().toUint256()));

        tradeAmount = tradeAmount.wadDiv(perpetual.indexPrice().toUint256());

        vm.startPrank(alice);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Short);
        vm.stopPrank();
        LibPerpetual.TraderPosition memory alicePositionBefore = perpetual.getTraderPosition(alice);

        int256 aliceVaultBeforeClosing = vault.getReserveValue(alice, false);
        int256 bobVaultBeforeLiquidation = vault.getReserveValue(bob, false);
        uint256 insuranceBalanceBeforeLiquidation = ua.balanceOf(address(insurance));

        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        uint256 proposedAmount = viewer.getTraderProposedAmount(0, alice, 1e18, 40, 0);

        vm.expectEmit(true, true, true, false);
        emit LiquidationCall(0, alice, bob, proposedAmount, 0, 0, true);
        vm.startPrank(bob);
        clearingHouse.liquidateTrader(0, alice, proposedAmount, 0);
        vm.stopPrank();

        LibPerpetual.TraderPosition memory alicePosition = perpetual.getTraderPosition(alice);
        assertEq(alicePosition.openNotional, 0);
        assertEq(alicePosition.positionSize, 0);

        int256 aliceVaultBalanceAfterClosing = vault.getReserveValue(alice, false);
        assertLt(aliceVaultBalanceAfterClosing, aliceVaultBeforeClosing);

        uint256 liquidationRewardAmount =
            int256(alicePositionBefore.openNotional).toUint256().wadMul(clearingHouse.liquidationReward());
        uint256 liquidationRewardInsuranceShare = clearingHouse.liquidationRewardInsuranceShare();
        uint256 liquidatorLiquidationReward = liquidationRewardAmount.wadMul(1 ether - liquidationRewardInsuranceShare);
        uint256 insuranceLiquidationReward = liquidationRewardAmount.wadMul(liquidationRewardInsuranceShare);

        int256 bobVaultBalanceAfterLiquidation = vault.getReserveValue(bob, false);
        assertApproxEqAbs(
            bobVaultBalanceAfterLiquidation, bobVaultBeforeLiquidation + liquidatorLiquidationReward.toInt256(), 1
        );

        uint256 insuranceBalanceAfterLiquidation = ua.balanceOf(address(insurance));
        assertApproxEqAbs(
            insuranceBalanceAfterLiquidation.toInt256(),
            insuranceBalanceBeforeLiquidation.toInt256() + insuranceLiquidationReward.toInt256(),
            1
        );
    }

    function testFuzz_LiquidationWithMarginInLiquidationRewardThresholdShouldNotGenerateBadDebt(uint256 tradeAmount)
        public
    {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);
        _dealUaAndDeposit(alice, tradeAmount.wadDiv(clearingHouse.minMarginAtCreation().toUint256()));

        uint256 aliceTradeAmount = tradeAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(alice);
        clearingHouse.changePosition(0, aliceTradeAmount, 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        int256 aliceOpenNotional = perpetual.getTraderPosition(alice).openNotional;

        int256 bobVaultBeforeLiquidation = vault.getReserveValue(bob, false);
        uint256 insuranceBalanceBeforeLiquidation = ua.balanceOf(address(insurance));

        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        uint256 proposedAmount = viewer.getTraderProposedAmount(0, alice, 1e18, 40, 0);

        vm.expectEmit(true, true, true, false);
        emit LiquidationCall(0, alice, bob, proposedAmount, 0, 0, true);
        vm.startPrank(bob);
        clearingHouse.liquidateTrader(0, alice, proposedAmount, 0);
        vm.stopPrank();

        assertTrue(!perpetual.isTraderPositionOpen(alice));

        uint256 liquidationRewardAmount = aliceOpenNotional.toUint256().wadMul(clearingHouse.liquidationReward());
        uint256 liquidationRewardInsuranceShare = clearingHouse.liquidationRewardInsuranceShare();
        uint256 liquidatorLiquidationReward = liquidationRewardAmount.wadMul(1 ether - liquidationRewardInsuranceShare);
        uint256 insuranceLiquidationReward = liquidationRewardAmount.wadMul(liquidationRewardInsuranceShare);

        int256 bobVaultBalanceAfterLiquidation = vault.getReserveValue(bob, false);
        assertApproxEqAbs(
            bobVaultBalanceAfterLiquidation, bobVaultBeforeLiquidation + liquidatorLiquidationReward.toInt256(), 1
        );

        uint256 insuranceBalanceAfterLiquidation = ua.balanceOf(address(insurance));
        assertApproxEqAbs(
            insuranceBalanceAfterLiquidation.toInt256(),
            insuranceBalanceBeforeLiquidation.toInt256() + insuranceLiquidationReward.toInt256(),
            1
        );

        assertGt(vault.getReserveValue(alice, false), 0);
    }

    function test_LiquidateLpWhenUnderMarginRequirement(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);

        _dealUaAndDeposit(alice, tradeAmount * 2);

        uint256 quoteAmount = tradeAmount;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(alice);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        assertTrue(!viewer.isMarginValid(alice, clearingHouse.minMargin()));

        int256 positionOpenNotional = perpetual.getLpOpenNotional(alice).abs();
        int256 bobVaultBeforeLiquidation = vault.getReserveValue(bob, false);
        uint256 insuranceBalanceBeforeLiquidation = ua.balanceOf(address(insurance));

        int256 estimatedProfit = viewer.getLpEstimatedPnl(0, alice);
        int256 estimatedFunding = viewer.getLpFundingPayments(0, alice);

        uint256 liquidationRewardAmount = positionOpenNotional.toUint256().wadMul(clearingHouse.liquidationReward());
        int256 estimatedLpProfit = estimatedProfit + estimatedFunding - liquidationRewardAmount.toInt256();
        uint256 liquidationRewardInsuranceShare = clearingHouse.liquidationRewardInsuranceShare();
        uint256 liquidatorLiquidationReward = liquidationRewardAmount.wadMul(1 ether - liquidationRewardInsuranceShare);
        uint256 insuranceLiquidationReward = liquidationRewardAmount.wadMul(liquidationRewardInsuranceShare);

        uint256 proposedAmount = viewer.getLpProposedAmount(0, alice, 1e18, 40, [uint256(0), uint256(0)], 0);

        vm.expectEmit(true, true, true, false);
        emit LiquidationCall(
            0, alice, bob, positionOpenNotional.toUint256(), estimatedLpProfit, estimatedFunding, false
        );
        vm.startPrank(bob);
        clearingHouse.liquidateLp(0, alice, [uint256(0), uint256(0)], proposedAmount, 0);
        vm.stopPrank();

        assertApproxEqAbs(
            vault.getReserveValue(bob, false), bobVaultBeforeLiquidation + liquidatorLiquidationReward.toInt256(), 1
        );
        assertApproxEqAbs(
            ua.balanceOf(address(insurance)), insuranceBalanceBeforeLiquidation + insuranceLiquidationReward, 1
        );
    }

    function testFuzz_FailsWhenLpHasPositionOpenAndLessThanUADebtThreshold(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);

        // provide liquidity as alice
        _dealUaAndDeposit(alice, tradeAmount * 2);
        uint256 quoteAmount = tradeAmount;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(alice);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        int256 aliceUaVaultBalance = vault.getBalance(alice, 0);
        int256 debtThreshold = clearingHouse.uaDebtSeizureThreshold();
        vault.__TestVault__changeTraderBalance(alice, 0, -(aliceUaVaultBalance + debtThreshold));

        assertTrue(!clearingHouse.canSeizeCollateral(alice));

        vm.expectRevert(IClearingHouse.ClearingHouse_SufficientUserCollateral.selector);
        clearingHouse.seizeCollateral(alice);
    }

    function testFuzz_SeizedCollateralWhenLpHasPositionOpenWithMoreThanUADebtThreshold(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);

        // provide liquidity as alice
        _dealUaAndDeposit(alice, tradeAmount * 2);
        uint256 quoteAmount = tradeAmount;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(alice);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        int256 aliceUaVaultBalance = vault.getBalance(alice, 0);
        int256 debtThreshold = clearingHouse.uaDebtSeizureThreshold();
        vault.__TestVault__changeTraderBalance(alice, 0, -(aliceUaVaultBalance + debtThreshold + 1));

        assertTrue(clearingHouse.canSeizeCollateral(alice));

        vm.expectEmit(true, true, true, false);
        emit SeizeCollateral(alice, address(this));
        clearingHouse.seizeCollateral(alice);
    }

    function testFuzz_FailsToSeizeCollateralWhenNoLpDebt(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);
        _fundLiquidityPool(0, tradeAmount);

        vm.expectRevert(IClearingHouse.ClearingHouse_LiquidationDebtSizeZero.selector);
        clearingHouse.canSeizeCollateral(lp);

        vm.expectRevert(IClearingHouse.ClearingHouse_LiquidationDebtSizeZero.selector);
        clearingHouse.seizeCollateral(lp);
    }

    function testFuzz_SeizesNonUACollateralsOfLpWithUaDebtAndInsuranceFillsGap(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);
        _fundLiquidityPool(0, tradeAmount);

        insurance.__TestInsurance__fundInsurance(tradeAmount);

        // deposit ua and usdc to vault as alice
        _dealUaAndDeposit(alice, tradeAmount);
        _dealUsdcAndDeposit(alice, tradeAmount);

        // deposit ua to vault as bob
        _dealUaAndDeposit(bob, tradeAmount);

        int256 initialAliceUSDCBalance = vault.getBalance(alice, 1);
        // provide liquidity as alice
        uint256 quoteAmount = tradeAmount;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(alice);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        // change alice's ua vault balance to be below the threshold
        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        // liquidate alice
        uint256 proposedAmount = viewer.getLpProposedAmount(0, alice, 1e18, 40, [uint256(0), uint256(0)], 0);
        vm.expectEmit(true, true, true, false);
        emit LiquidationCall(0, alice, bob, tradeAmount, 0, 0, false);
        vm.startPrank(bob);
        clearingHouse.liquidateLp(0, alice, [uint256(0), uint256(0)], proposedAmount, 0);
        vm.stopPrank();

        int256 usdcBalance = vault.getBalance(alice, 1);
        int256 usdcCollateralValue = vault.__TestVault__getUndiscountedCollateralUSDValue(usdc, usdcBalance);
        int256 usdcDiscountedValue = usdcCollateralValue.wadMul(clearingHouse.liquidationDiscount().toInt256());

        // deal bob some ua and approve vault
        deal(address(ua), bob, usdcDiscountedValue.toUint256());
        vm.startPrank(bob);
        ua.approve(address(vault), usdcDiscountedValue.toUint256());
        vm.stopPrank();

        // grab values before seizing collateral
        uint256 insuranceBalanceBeforeSeize = ua.balanceOf(address(insurance));
        int256 liquidateeBalanceBeforeSeize = vault.getBalance(alice, 0);

        // seize collateral
        vm.expectEmit(true, false, false, false);
        emit TraderBadDebtGenerated(alice, usdcDiscountedValue.toUint256());
        vm.expectEmit(true, true, true, false);
        emit SeizeCollateral(alice, bob);
        vm.startPrank(bob);
        clearingHouse.seizeCollateral(alice);
        vm.stopPrank();

        // check liquidator balance change
        uint256 liquidatorUABalanceAfterSeize = ua.balanceOf(bob);
        int256 liquidatorUSDCBalanceAfterSeize = vault.getBalance(bob, 1);

        assertEq(liquidatorUABalanceAfterSeize.toInt256(), 0);
        assertEq(liquidatorUSDCBalanceAfterSeize, initialAliceUSDCBalance);

        // check liquidatee balance change
        int256 aliceUADebtAfterUSDCCollateralSellOff = vault.getBalance(alice, 0);
        assertEq(aliceUADebtAfterUSDCCollateralSellOff, 0);
        int256 aliceUSDCBalanceAfterUSDCCollateralSellOff = vault.getBalance(alice, 1);
        assertEq(aliceUSDCBalanceAfterUSDCCollateralSellOff, 0);

        // check insurance balance change
        int256 expectedInsuranceUABalanceDiff = (liquidateeBalanceBeforeSeize + usdcDiscountedValue).abs();
        uint256 expectedInsuranceUABalanceAfterSeize = insuranceBalanceBeforeSeize
            > expectedInsuranceUABalanceDiff.toUint256()
            ? insuranceBalanceBeforeSeize - expectedInsuranceUABalanceDiff.toUint256()
            : 0;
        uint256 insuranceUABalanceAfterSeize = ua.balanceOf(address(insurance));
        assertEq(insuranceUABalanceAfterSeize, expectedInsuranceUABalanceAfterSeize);
    }

    function testFuzz_LiquidateTradingAndLpPositionInOneMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);
        _dealUaAndDeposit(address(this), tradeAmount);
        insurance.__TestInsurance__fundInsurance(tradeAmount);
        _fundLiquidityPool(0, tradeAmount);

        // fund alice account
        _dealUaAndDeposit(alice, tradeAmount);
        _dealUsdcAndDeposit(alice, tradeAmount);

        // open trader position
        vm.startPrank(alice);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // open lp position
        uint256 quoteAmount = tradeAmount;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(alice);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        // change alice's ua vault balance to be below the threshold
        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        // liquidate trader position
        uint256 proposedAmount = viewer.getTraderProposedAmount(0, alice, 1e18, 40, 0);
        vm.expectEmit(true, true, true, false);
        emit LiquidationCall(0, alice, bob, tradeAmount, 0, 0, true);
        vm.startPrank(bob);
        clearingHouse.liquidateTrader(0, alice, proposedAmount, 0);
        vm.stopPrank();

        // change alice's ua vault balance to be below the threshold
        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        // liquidate lp position
        uint256 proposedAmount2 = viewer.getLpProposedAmount(0, alice, 1e18, 40, [uint256(0), uint256(0)], 0);
        vm.expectEmit(true, true, true, false);
        emit LiquidationCall(0, alice, bob, tradeAmount, 0, 0, false);
        vm.startPrank(bob);
        clearingHouse.liquidateLp(0, alice, [uint256(0), uint256(0)], proposedAmount2, 0);
        vm.stopPrank();

        // seize collateral
        int256 aliceUSDCVaultBalance =
            vault.__TestVault__getUndiscountedCollateralUSDValue(usdc, vault.getBalance(alice, 1));
        int256 aliceUAVaultBalance = vault.getBalance(alice, 0);
        int256 discountedUSDCValue = aliceUSDCVaultBalance.wadMul(clearingHouse.liquidationDiscount().toInt256());

        int256 insuranceUABalanceBeforeSeize = ua.balanceOf(address(insurance)).toInt256();
        int256 uaDebtRemainingAfterCollateralSale = (aliceUAVaultBalance + discountedUSDCValue).abs();

        deal(address(ua), bob, discountedUSDCValue.toUint256());
        vm.startPrank(bob);
        ua.approve(address(vault), discountedUSDCValue.toUint256());
        vm.stopPrank();

        emit TraderBadDebtGenerated(alice, uaDebtRemainingAfterCollateralSale.toUint256());
        vm.startPrank(bob);
        clearingHouse.seizeCollateral(alice);
        vm.stopPrank();

        int256 expectedInsuranceUABalanceAfterSeize = insuranceUABalanceBeforeSeize - uaDebtRemainingAfterCollateralSale;

        assertEq(vault.getBalance(alice, 0), 0);
        assertEq(ua.balanceOf(bob).toInt256(), 0);
        assertEq(ua.balanceOf(address(insurance)).toInt256(), 0);
        assertEq(insurance.systemBadDebt(), expectedInsuranceUABalanceAfterSeize.abs().toUint256());
    }

    function testFuzz_LiquidateUserAcrossMultipleMarkets(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealUaAndDeposit(alice, tradeAmount);
        _fundLiquidityPool(0, tradeAmount);

        // create position in eur market
        uint256 sellAmount = tradeAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(alice);
        clearingHouse.changePosition(0, sellAmount, 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        _deployEthMarket();
        _dealUaAndDeposit(alice, tradeAmount);
        _fundLiquidityPool(1, tradeAmount);

        // create position in eth market
        sellAmount = tradeAmount.wadDiv(eth_perpetual.indexPrice().toUint256());
        vm.startPrank(alice);
        clearingHouse.changePosition(1, sellAmount, 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        _setTraderBelowMargin(alice, clearingHouse.minMargin());

        // grab values before liquidation
        int256 aliceUABalanceInitial = vault.getBalance(alice, 0);
        LibPerpetual.TraderPosition memory alicePositionBefore = perpetual.getTraderPosition(alice);
        uint256 proposedAmount = viewer.getTraderProposedAmount(0, alice, 1e18, 40, 0);

        // liquidate alice in eur market
        vm.expectEmit(true, true, true, false);
        emit LiquidationCall(0, alice, bob, int256(alicePositionBefore.openNotional).abs().toUint256(), 0, 0, true);
        vm.startPrank(bob);
        clearingHouse.liquidateTrader(0, alice, proposedAmount, 0);
        vm.stopPrank();

        // check values after first liquidation
        int256 aliceUABalanceAfterFirstLiq = vault.getBalance(alice, 0);

        _setTraderBelowMargin(alice, clearingHouse.minMargin());
        assertTrue(!viewer.isMarginValid(alice, clearingHouse.minMargin()));
        proposedAmount = viewer.getTraderProposedAmount(1, alice, 1e18, 40, 0);

        // liquidate alice in eth market
        vm.expectEmit(true, true, true, false);
        emit LiquidationCall(1, alice, bob, int256(alicePositionBefore.openNotional).abs().toUint256(), 0, 0, true);
        vm.startPrank(bob);
        clearingHouse.liquidateTrader(1, alice, proposedAmount, 0);
        vm.stopPrank();

        // check values after second liquidation
        int256 aliceUABalanceAfterSecondLiq = vault.getBalance(alice, 0);
        assertLt(aliceUABalanceAfterFirstLiq, aliceUABalanceInitial);
        assertLt(aliceUABalanceAfterSecondLiq, aliceUABalanceAfterFirstLiq);
    }

    function testFuzz_CalculateMarginRatioOfCryptoMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 4);

        _deployEthMarket();
        _fundLiquidityPool(0, tradeAmount * 2);
        _fundLiquidityPool(1, tradeAmount * 2);

        _dealUaAndDeposit(alice, tradeAmount);

        // create position in eth market
        vm.startPrank(alice);
        clearingHouse.changePosition(1, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // get values after opening eth position
        int256 reserveValue = vault.getReserveValue(alice, false);
        int256 ethPnL = viewer.getTraderUnrealizedPnL(1, alice);
        int256 ethOpenNotional = int256(viewer.getTraderPosition(1, alice).openNotional).abs();

        assertEq(
            viewer.marginRatio(alice),
            (reserveValue + ethPnL).wadDiv(ethOpenNotional.wadMul(eth_perpetual.riskWeight().toInt256()))
        );

        // create position in eur market
        vm.startPrank(alice);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // get values after opening eur position
        reserveValue = vault.getReserveValue(alice, false);
        int256 eurPnL = viewer.getTraderUnrealizedPnL(0, alice);
        int256 eurOpenNotional = int256(viewer.getTraderPosition(0, alice).openNotional).abs();

        assertEq(
            viewer.marginRatio(alice),
            (reserveValue + ethPnL + eurPnL).wadDiv(
                ethOpenNotional.wadMul(eth_perpetual.riskWeight().toInt256()) + eurOpenNotional
            )
        );
    }

    function testFuzz_FailsToSeizeCollateralOfUserWithWithLessThanUADebtThreshold(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);

        _fundLiquidityPool(0, tradeAmount);
        _dealUaAndDeposit(alice, tradeAmount);

        // open position
        vm.startPrank(alice);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // change alice's ua vault balance to negative value
        vault.__TestVault__changeTraderBalance(alice, 0, -int256(tradeAmount));

        // should fail to seize collatreral
        assertTrue(!clearingHouse.canSeizeCollateral(alice));
        vm.expectRevert(IClearingHouse.ClearingHouse_SufficientUserCollateral.selector);
        clearingHouse.seizeCollateral(alice);
    }

    function test_FailsToSeizeCollateralWhenNoUADebt() public {
        vm.expectRevert(IClearingHouse.ClearingHouse_LiquidationDebtSizeZero.selector);
        clearingHouse.canSeizeCollateral(alice);
        vm.expectRevert(IClearingHouse.ClearingHouse_LiquidationDebtSizeZero.selector);
        clearingHouse.seizeCollateral(alice);
    }

    function testFuzz_FailsToSeizeCollateralWhenNonUABalanceLargerThanDebt(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);
        _dealUsdcAndDeposit(alice, tradeAmount);

        // remove uaDebtSeizureThreshold
        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams(
            clearingHouse.minMargin(),
            clearingHouse.minMarginAtCreation(),
            clearingHouse.minPositiveOpenNotional(),
            clearingHouse.liquidationReward(),
            clearingHouse.insuranceRatio(),
            clearingHouse.liquidationRewardInsuranceShare(),
            clearingHouse.liquidationDiscount(),
            clearingHouse.nonUACollSeizureDiscount(),
            type(int256).max
        );
        clearingHouse.setParameters(params);

        // set ua debt just under usdc value
        int256 reserveValue = vault.getReserveValue(alice, true);
        int256 nonUACollSeizureDiscount = clearingHouse.nonUACollSeizureDiscount().toInt256();
        vault.__TestVault__changeTraderBalance(alice, 0, -reserveValue.wadMul(nonUACollSeizureDiscount));

        vm.expectRevert(IClearingHouse.ClearingHouse_SufficientUserCollateral.selector);
        clearingHouse.seizeCollateral(alice);
    }

    function testFuzz_FailsToSeizeCollateralWhenUADebtLessThanUADebtSeizureThreshold(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);
        _dealUsdcAndDeposit(alice, tradeAmount);

        // set ua debt just under usdc value
        vault.__TestVault__changeTraderBalance(alice, 0, -(clearingHouse.uaDebtSeizureThreshold()));

        vm.expectRevert(IClearingHouse.ClearingHouse_SufficientUserCollateral.selector);
        clearingHouse.seizeCollateral(alice);
    }

    function testFuzz_SeizeOneAssetCompletely(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);
        _dealUsdcAndDeposit(alice, tradeAmount);

        // remove uaDebtSeizureThreshold
        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams(
            clearingHouse.minMargin(),
            clearingHouse.minMarginAtCreation(),
            clearingHouse.minPositiveOpenNotional(),
            clearingHouse.liquidationReward(),
            clearingHouse.insuranceRatio(),
            clearingHouse.liquidationRewardInsuranceShare(),
            clearingHouse.liquidationDiscount(),
            clearingHouse.nonUACollSeizureDiscount(),
            type(int256).max
        );
        clearingHouse.setParameters(params);

        // set ua debt just over usdc value
        int256 reserveValue = vault.getReserveValue(alice, true);
        vault.__TestVault__changeTraderBalance(alice, 0, -reserveValue);
        emit log_named_int("Alice balance before", vault.getBalance(alice, 1));

        // seize collateral as bob
        deal(address(ua), bob, type(uint256).max);
        vm.startPrank(bob);
        ua.approve(address(vault), type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit SeizeCollateral(alice, bob);
        clearingHouse.seizeCollateral(alice);
        vm.stopPrank();

        // ensure alice's balance is gone
        assertEq(vault.getBalance(alice, 1), 0);
    }

    function testFuzz_SeizeCollateralWhenDebtExceedsThreshold(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);
        _dealUsdcAndDeposit(alice, tradeAmount);

        // set ua debt just under usdc value
        vault.__TestVault__changeTraderBalance(alice, 0, -(clearingHouse.uaDebtSeizureThreshold()) - 1);

        int256 balanceBeforeLiquidation = vault.getBalance(alice, 1);

        // seize collateral as bob
        deal(address(ua), bob, clearingHouse.uaDebtSeizureThreshold().toUint256() + 1);
        vm.startPrank(bob);
        ua.approve(address(vault), clearingHouse.uaDebtSeizureThreshold().toUint256() + 1);
        vm.expectEmit(true, true, true, true);
        emit SeizeCollateral(alice, bob);
        clearingHouse.seizeCollateral(alice);
        vm.stopPrank();

        // ensure alice's balance is gone
        assertGt(balanceBeforeLiquidation, vault.getBalance(alice, 1));
    }
}
