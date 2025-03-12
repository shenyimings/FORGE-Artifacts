// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";

// interfaces
import "../../contracts/interfaces/IClearingHouse.sol";

// libraries
import "../../contracts/lib/LibMath.sol";
import "../../contracts/lib/LibReserve.sol";
import "../../contracts/lib/LibPerpetual.sol";
import "../../lib/forge-std/src/StdError.sol";

contract Liquidation is Deployment {
    // events
    event LiquidityRemoved(
        uint256 indexed idx,
        address indexed liquidityProvider,
        uint256 reductionRatio,
        int256 profit,
        int256 tradingFeesPayed,
        bool isPositionClosed
    );
    event AddLiquidity(address indexed provider, uint256[2] token_amounts, uint256 fee, uint256 token_supply);

    // libraries
    using LibMath for uint256;
    using LibMath for int256;

    // addresses
    address lp = address(123);
    address lp2 = address(456);
    address trader = address(789);

    // config values
    uint256 maxTradeAmount;
    uint256 minTradeAmount;
    uint256 maxLiquidityAmount;
    uint24 usdcHeartBeat = 25 hours;
    uint256 vBaseLastUpdate;

    function _dealAndDeposit(address addr, uint256 amount) internal {
        deal(address(ua), addr, amount);

        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        clearingHouse.deposit(amount, ua);
        vm.stopPrank();
    }

    function _dealUSDCAndDeposit(address addr, uint256 amount) internal {
        bool isWhitelisted = vault.tokenToCollateralIdx(usdc) != 0;
        amount = LibReserve.wadToToken(usdc.decimals(), amount);

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

    function _dealAndProvideLiquidity(address addr, uint256 amount) internal {
        _dealAndDeposit(addr, amount);
        uint256 quoteAmount = amount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(addr);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function _getTokensToWithdraw(
        LibPerpetual.GlobalPosition memory globalPosition,
        LibPerpetual.LiquidityProviderPosition memory lpPosition
    ) internal view returns (uint256 withdrawnQuoteTokensExFees, uint256 withdrawnBaseTokensExFees) {
        withdrawnQuoteTokensExFees = (
            ((lpPosition.liquidityBalance - 1) * cryptoSwap.balances(0)) / lpToken.totalSupply()
        ).wadDiv(1 ether + globalPosition.totalQuoteFeesGrowth - lpPosition.totalQuoteFeesGrowth);
        withdrawnBaseTokensExFees = (
            ((lpPosition.liquidityBalance - 1) * cryptoSwap.balances(1)) / lpToken.totalSupply()
        ).wadDiv(1 ether + globalPosition.totalBaseFeesGrowth - lpPosition.totalBaseFeesGrowth);
    }

    function _getLpProfit(address addr) internal returns (int256) {
        LibPerpetual.LiquidityProviderPosition memory lpPosition = perpetual.getLpPosition(addr);
        LibPerpetual.TraderPosition memory lpPositionAfterWithdrawal = perpetual.getLpPositionAfterWithdrawal(addr);

        uint256 snapshotId = vm.snapshot();
        uint256 proposedAmount = viewer.getLpProposedAmount(0, addr, 1 ether, 100, [uint256(0), uint256(0)], 0);

        // remove lp liquidity
        vm.startPrank(address(perpetual));
        cryptoSwap.remove_liquidity(lpPosition.liquidityBalance, [uint256(0), uint256(0)]);
        vm.stopPrank();

        // get profit
        int256 quoteProceeds;
        int256 percentageFee;
        if (lpPositionAfterWithdrawal.positionSize > 0) {
            quoteProceeds = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, 1, 0, proposedAmount).toInt256();
            percentageFee = curveCryptoViews.get_dy_fees_perc(cryptoSwap, 1, 0, proposedAmount).toInt256();
        } else {
            quoteProceeds = -proposedAmount.toInt256();
            percentageFee = curveCryptoViews.get_dy_fees_perc(cryptoSwap, 0, 1, proposedAmount).toInt256();
        }
        int256 quoteOnlyFees = quoteProceeds.abs().wadMul(percentageFee);
        int256 positionPnL = lpPositionAfterWithdrawal.openNotional + quoteProceeds;
        int256 pnl = positionPnL - quoteOnlyFees;

        vm.revertTo(snapshotId);
        int256 insuranceFee = quoteProceeds.abs().wadMul(perpetual.insuranceFee());

        // get trading fees
        LibPerpetual.GlobalPosition memory globalPosition = perpetual.getGlobalPosition();
        uint256 tradingFeesEarned = uint256(globalPosition.totalTradingFeesGrowth - lpPosition.totalTradingFeesGrowth)
            .wadMul(lpPosition.liquidityBalance);

        return pnl + tradingFeesEarned.toInt256() - insuranceFee;
    }

    function setUp() public virtual override {
        super.setUp();
        maxTradeAmount = perpetual.maxPosition();
        minTradeAmount = clearingHouse.minPositiveOpenNotional();

        uint256 totalQuoteProvided = perpetual.getGlobalPosition().totalQuoteProvided;
        maxLiquidityAmount = perpetual.maxLiquidityProvided() - totalQuoteProvided;
        (,,, vBaseLastUpdate,) = baseOracle.latestRoundData();
    }

    function testFuzz_FailsToDepositZeroAmount(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256());
        _dealAndDeposit(lp, depositAmount);

        vm.expectRevert(IClearingHouse.ClearingHouse_ProvideLiquidityZeroAmount.selector);
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [uint256(0), uint256(0)], 0);
        vm.stopPrank();
    }

    function test_FailsToAddTooMuchLiquidity() public {
        uint256 quoteAmount = maxLiquidityAmount + 1;

        _dealAndDeposit(lp, quoteAmount * 2);

        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());

        // should fail with too much quote
        vm.expectRevert(IPerpetual.Perpetual_MaxLiquidityProvided.selector);
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        // should pass with exactly max quote
        quoteAmount -= 1;
        baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function test_FailsToAddTooLittleLiquidity() public {
        uint256 minQuoteAmount = clearingHouse.minPositiveOpenNotional();

        _dealAndDeposit(lp, minQuoteAmount * 2);

        uint256 quoteAmount = minQuoteAmount - 1;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());

        // should fail with too little quote
        vm.expectRevert(IClearingHouse.ClearingHouse_UnderOpenNotionalAmountRequired.selector);
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        // should pass with exactly min quote
        quoteAmount = minQuoteAmount;
        baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function testFuzz_LiquidityDoesNotExceedFreeCollateral(uint256 quoteAmount) public {
        quoteAmount = bound(quoteAmount, minTradeAmount + 1, maxLiquidityAmount);

        _dealAndDeposit(lp, (quoteAmount - 1) * 2);

        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());

        // should fail to deposit more than free collateral
        vm.expectRevert(IClearingHouse.ClearingHouse_AmountProvidedTooLarge.selector);
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        // should be allowed to deposit exact amount of free collateral
        quoteAmount -= 1;
        baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function test_ReturnsEmptyPositionAfterWithdrawForLpWithoutPosition() public {
        LibPerpetual.TraderPosition memory lpPositionAfterWithdrawal = perpetual.getLpPositionAfterWithdrawal(lp);
        assertEq(lpPositionAfterWithdrawal.openNotional, 0);
        assertEq(lpPositionAfterWithdrawal.positionSize, 0);
        assertEq(lpPositionAfterWithdrawal.cumFundingRate, 0);
    }

    function testFuzz_FailsToWithdrawMoreThanDeposited(uint256 quoteAmount) public {
        quoteAmount = bound(quoteAmount, minTradeAmount, maxLiquidityAmount);

        // provide liquidity
        _dealAndProvideLiquidity(lp, quoteAmount * 2);
        LibPerpetual.LiquidityProviderPosition memory lpPosition = viewer.getLpPosition(0, lp);

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // should fail to remove too much liquidity
        vm.expectRevert(IPerpetual.Perpetual_MarketBalanceTooLow.selector);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(0, lpPosition.liquidityBalance, [uint256(0), uint256(0)], 0, 0);
        vm.stopPrank();
    }

    function testFuzz_FailsToWithdrawBelowThreshold(uint256 quoteAmount) public {
        quoteAmount = bound(quoteAmount, minTradeAmount * 2, maxLiquidityAmount / 2);

        // provide liquidity
        _dealAndProvideLiquidity(lp, quoteAmount * 2);
        LibPerpetual.LiquidityProviderPosition memory lpPosition = viewer.getLpPosition(0, lp);

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // should fail to withdraw amount resulting in quote below min open notional
        uint256 portionToRemove = (int256(lpPosition.openNotional).abs() - (minTradeAmount.toInt256() - 1 ether)).wadDiv(
            int256(lpPosition.openNotional).abs()
        ).toUint256();
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp, portionToRemove, 100, [uint256(0), uint256(0)], 0);
        vm.expectRevert(IClearingHouse.ClearingHouse_UnderOpenNotionalAmountRequired.selector);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(
            0, uint256(lpPosition.liquidityBalance).wadMul(portionToRemove), [uint256(0), uint256(0)], proposedAmount, 0
        );
        vm.stopPrank();

        // should succeed at removing amount resulting in exact min open notional quote amount
        portionToRemove = (int256(lpPosition.openNotional).abs() - minTradeAmount.toInt256()).wadDiv(
            int256(lpPosition.openNotional).abs()
        ).toUint256();
        proposedAmount = viewer.getLpProposedAmount(0, lp, portionToRemove, 100, [uint256(0), uint256(0)], 0);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(
            0, uint256(lpPosition.liquidityBalance).wadMul(portionToRemove), [uint256(0), uint256(0)], proposedAmount, 0
        );
        vm.stopPrank();

        // suppliment liquidity
        _dealAndProvideLiquidity(lp2, quoteAmount * 2);
        lpPosition = viewer.getLpPosition(0, lp);

        // or remove the entire amount
        proposedAmount = viewer.getLpProposedAmount(0, lp, 1 ether, 100, [uint256(0), uint256(0)], 0);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(0, lpPosition.liquidityBalance, [uint256(0), uint256(0)], proposedAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AllowsDepositTwice(uint256 firstQuoteAmount, uint256 secondQuoteAmount) public {
        firstQuoteAmount = bound(firstQuoteAmount, minTradeAmount * 2, maxLiquidityAmount / 2);
        secondQuoteAmount = bound(secondQuoteAmount, minTradeAmount * 2, maxLiquidityAmount / 2);

        _dealAndDeposit(lp, (firstQuoteAmount + secondQuoteAmount) * 2);

        vm.startPrank(lp);
        clearingHouse.provideLiquidity(
            0, [firstQuoteAmount, firstQuoteAmount.wadDiv(perpetual.indexPrice().toUint256())], 0
        );
        clearingHouse.provideLiquidity(
            0, [secondQuoteAmount, secondQuoteAmount.wadDiv(perpetual.indexPrice().toUint256())], 0
        );
        vm.stopPrank();
    }

    function testFuzz_SplitFirstDepositWithRatioFromChainlinkPrice(uint256 quoteAmount) public {
        quoteAmount = bound(quoteAmount, minTradeAmount, maxLiquidityAmount / 2);

        _dealAndProvideLiquidity(lp2, quoteAmount * 2);

        uint256 vBaseBefore = vBase.balanceOf(address(cryptoSwap));
        uint256 vQuoteBefore = vQuote.balanceOf(address(cryptoSwap));
        uint256 vBaseLpBalanceBefore = cryptoSwap.balances(1);
        uint256 vQuoteLpBalanceBefore = cryptoSwap.balances(0);

        uint256 chainlinkPrice = perpetual.indexPrice().toUint256();
        uint256 initialTokenSupply = lpToken.balanceOf(address(perpetual));
        uint256 initialTotalLiquidityProvided = perpetual.getTotalLiquidityProvided();
        LibPerpetual.GlobalPosition memory initialGlobalPosition = perpetual.getGlobalPosition();

        assertEq(vBaseBefore, vBaseLpBalanceBefore);
        assertEq(vQuoteBefore, vQuoteLpBalanceBefore);

        _dealAndProvideLiquidity(lp, quoteAmount * 2);

        assertEq(vBase.balanceOf(address(cryptoSwap)), vBaseBefore + quoteAmount.wadDiv(chainlinkPrice));
        assertEq(vQuote.balanceOf(address(cryptoSwap)), vQuoteBefore + quoteAmount);
        assertEq(cryptoSwap.balances(1), vBaseLpBalanceBefore + quoteAmount.wadDiv(chainlinkPrice));
        assertEq(cryptoSwap.balances(0), vQuoteLpBalanceBefore + quoteAmount);

        LibPerpetual.LiquidityProviderPosition memory lpPosition = perpetual.getLpPosition(lp);
        assertEq(int256(lpPosition.openNotional).abs().toUint256(), quoteAmount);
        assertEq(int256(lpPosition.positionSize).abs().toUint256(), quoteAmount.wadDiv(chainlinkPrice));

        assertEq(lpPosition.liquidityBalance, lpToken.balanceOf(address(perpetual)) - initialTokenSupply);
        assertEq(
            perpetual.getTotalLiquidityProvided() - initialTotalLiquidityProvided,
            lpToken.balanceOf(address(perpetual)) - initialTokenSupply
        );

        LibPerpetual.GlobalPosition memory globalPosition = perpetual.getGlobalPosition();
        assertEq(globalPosition.totalQuoteProvided, quoteAmount + initialGlobalPosition.totalQuoteProvided);
        assertEq(
            globalPosition.totalBaseProvided,
            quoteAmount.wadDiv(chainlinkPrice) + initialGlobalPosition.totalBaseProvided
        );
    }

    function test_ShouldAllowMultipleDepositsAroundTrades(uint256 lpQuoteAmount, uint256 traderQuoteAmount) public {
        lpQuoteAmount = bound(lpQuoteAmount, minTradeAmount, maxLiquidityAmount / 2);
        traderQuoteAmount = bound(traderQuoteAmount, minTradeAmount, (lpQuoteAmount).min(maxTradeAmount));

        // provide liquidity
        _dealAndProvideLiquidity(lp, lpQuoteAmount * 2);
        assertEq(perpetual.getLpTradingFees(lp), 0);

        // make trade
        _dealAndDeposit(trader, traderQuoteAmount);
        uint256 dyInclFees = cryptoSwap.get_dy(0, 1, traderQuoteAmount);
        vm.startPrank(trader);
        clearingHouse.changePosition(0, traderQuoteAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        assertGt(perpetual.getLpTradingFees(lp), 0);

        // record data after trade, before second lp
        uint256 vBaseBefore = vBase.balanceOf(address(cryptoSwap));
        uint256 vQuoteBefore = vQuote.balanceOf(address(cryptoSwap));
        uint256 vBaseLpBalance = cryptoSwap.balances(1);
        uint256 vQuoteLpBalance = cryptoSwap.balances(0);
        assertEq(vBaseBefore, vBaseLpBalance);
        assertEq(vQuoteBefore, vQuoteLpBalance);

        uint256 priceBefore = perpetual.indexPrice().toUint256();

        uint256 baseFeesToBeBurned;
        {
            LibPerpetual.LiquidityProviderPosition memory lpPosition = perpetual.getLpPosition(lp);
            LibPerpetual.GlobalPosition memory globalPosition = perpetual.getGlobalPosition();
            assertLt(lpPosition.totalTradingFeesGrowth, globalPosition.totalTradingFeesGrowth);
            uint256 withdrawnBaseTokens =
                ((lpPosition.liquidityBalance - 1) * cryptoSwap.balances(1)) / lpToken.totalSupply();
            uint256 withdrawnBaseTokensExFees = withdrawnBaseTokens.wadDiv(
                1 ether + globalPosition.totalBaseFeesGrowth - lpPosition.totalBaseFeesGrowth
            );
            baseFeesToBeBurned = withdrawnBaseTokens - withdrawnBaseTokensExFees;
        }

        // provide more liquidity
        _dealAndProvideLiquidity(lp, lpQuoteAmount * 2);

        // tradingFees should reset
        assertEq(
            perpetual.getLpPosition(lp).totalTradingFeesGrowth, perpetual.getGlobalPosition().totalTradingFeesGrowth
        );
        assertEq(perpetual.getLpTradingFees(lp), 0);

        // balances should change
        assertEq(vQuote.balanceOf(address(cryptoSwap)), vQuoteBefore + lpQuoteAmount);
        assertEq(
            vBase.balanceOf(address(cryptoSwap)), vBaseBefore + lpQuoteAmount.wadDiv(priceBefore) - baseFeesToBeBurned
        );
        assertEq(cryptoSwap.balances(1), vBaseLpBalance + lpQuoteAmount.wadDiv(priceBefore) - baseFeesToBeBurned);
        assertEq(cryptoSwap.balances(0), vQuoteLpBalance + lpQuoteAmount);

        LibPerpetual.LiquidityProviderPosition memory lpPositionAfter = perpetual.getLpPosition(lp);
        assertEq(
            int256(lpPositionAfter.openNotional).abs().toUint256(), vQuoteBefore + lpQuoteAmount - traderQuoteAmount
        );
        assertEq(
            int256(lpPositionAfter.positionSize).abs().toUint256(),
            vBaseBefore + lpQuoteAmount.wadDiv(priceBefore) + dyInclFees
        );

        assertEq(lpPositionAfter.liquidityBalance, lpToken.balanceOf(address(perpetual)));
        assertEq(perpetual.getTotalLiquidityProvided(), lpToken.balanceOf(address(perpetual)));
    }

    function testFuzz_DepositsInDesiredProportions(uint256 tradeAmount, int256 deviation) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        deviation = bound(deviation, -1 ether, 1 ether);

        // provide initial liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // open trade
        _dealAndDeposit(trader, tradeAmount);
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // provide liquidity
        _dealAndDeposit(lp2, tradeAmount * 4);
        uint256 quoteAmount = tradeAmount;
        uint256 baseAmount =
            tradeAmount.toInt256().wadMul(1 ether + deviation).wadDiv(perpetual.indexPrice()).toUint256();
        // should fail if out of bounds
        if (deviation.abs() > 1e17) vm.expectRevert(IPerpetual.Perpetual_LpAmountDeviation.selector);
        vm.startPrank(lp2);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function testFuzz_ShouldInitializeUserFundingRateWithGlobal(
        uint256 tradeAmount,
        uint256 timePassed,
        int256 newFundingRate
    ) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        timePassed = bound(timePassed, 1, 1000);
        newFundingRate = bound(newFundingRate, int256(type(int128).min), int256(type(int128).max));

        perpetual.__TestPerpetual__setGlobalPositionCumFundingPerLpToken(
            uint64(block.timestamp - timePassed), newFundingRate.toInt128()
        );

        _dealAndProvideLiquidity(lp, tradeAmount);

        assertEq(viewer.getLpPosition(0, lp).cumFundingPerLpToken, newFundingRate);
    }

    function testFuzz_FailsToWithdrawLiquidityWhenNoneIsProvided(uint256 withdrawAmount) public {
        withdrawAmount = bound(withdrawAmount, 1, type(int256).max.toUint256());
        vm.expectRevert(IPerpetual.Perpetual_LPWithdrawExceedsBalance.selector);
        clearingHouse.removeLiquidity(0, withdrawAmount, [uint256(0), uint256(0)], 0, 0);
    }

    function testFuzz_FailsToWithdrawMoreLiquidityThanProvided(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // attempt withdraw more than provided
        uint256 balance = perpetual.getLpPosition(lp).liquidityBalance;
        vm.expectRevert(IPerpetual.Perpetual_LPWithdrawExceedsBalance.selector);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(0, balance + 1, [uint256(0), uint256(0)], 0, 0);
        vm.stopPrank();
    }

    function testFuzz_FailsToWithdrawIfNotEnoughtLiquidityInPool(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // transfer out vBase
        uint256 vBaseBalance = vBase.balanceOf(address(cryptoSwap));
        vm.startPrank(address(cryptoSwap));
        vBase.transfer(address(0), vBaseBalance);
        vm.stopPrank();
        assertEq(vBase.balanceOf(address(cryptoSwap)), 0);

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // attempt withdraw
        uint256 lpBalance = perpetual.getLpPosition(lp).liquidityBalance;
        vm.expectRevert(stdError.arithmeticError);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(0, lpBalance, [uint256(0), uint256(0)], 0, 0);
        vm.stopPrank();
    }

    function testFuzz_FailsToWithdrawBeforeLockPeriod(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provide base liquidity
        _dealAndProvideLiquidity(lp2, tradeAmount * 2);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // skip to just before lock period
        vm.warp(block.timestamp + perpetual.lockPeriod() - 1);

        // attempt withdraw
        uint256 lpBalance = perpetual.getLpPosition(lp).liquidityBalance;
        vm.expectRevert(abi.encodeWithSelector(IPerpetual.Perpetual_LockPeriodNotReached.selector, block.timestamp + 1));
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(0, lpBalance, [uint256(0), uint256(0)], 0, 0);
        vm.stopPrank();

        // skip over lock period
        vm.warp(block.timestamp + 1);

        // withdraw
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp, 1 ether, 100, [uint256(0), uint256(0)], 0);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(0, lpBalance, [uint256(0), uint256(0)], proposedAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_CanRemoveLiquidity(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provide base liquidity
        _dealAndProvideLiquidity(lp2, tradeAmount * 2);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // grab initial balances
        LibPerpetual.LiquidityProviderPosition memory lpPosition = perpetual.getLpPosition(lp);
        uint256[2] memory tokensRemoved =
            viewer.getExpectedVirtualTokenAmountsFromLpTokenAmount(0, lp, lpPosition.liquidityBalance);
        LibPerpetual.GlobalPosition memory globalPositionBefore = perpetual.getGlobalPosition();

        // withdraw
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp, 1 ether, 100, [uint256(0), uint256(0)], 0);
        vm.expectEmit(true, true, true, false);
        emit LiquidityRemoved(0, lp, 1 ether, 0, 0, true);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(0, lpPosition.liquidityBalance, [uint256(0), uint256(0)], proposedAmount, 0);
        vm.stopPrank();

        LibPerpetual.GlobalPosition memory globalPositionAfter = perpetual.getGlobalPosition();

        // check balances
        assertEq(globalPositionAfter.totalQuoteProvided, globalPositionBefore.totalQuoteProvided - tokensRemoved[0]);
        assertEq(globalPositionAfter.totalBaseProvided, globalPositionBefore.totalBaseProvided - tokensRemoved[1]);
    }

    function testFuzz_CanRemoveAllLiquidityAsideFromMinPositiveOpenNotional(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // get portion to remove resulting in exactly minPositiveOpenNotional left
        LibPerpetual.LiquidityProviderPosition memory lpPosition = perpetual.getLpPosition(lp);
        uint256 portionToRemove = (int256(lpPosition.openNotional).abs() - minTradeAmount.toInt256()).wadDiv(
            int256(lpPosition.openNotional).abs()
        ).toUint256();
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp, portionToRemove, 100, [uint256(0), uint256(0)], 0);

        // withdraw
        vm.expectEmit(true, true, true, false);
        emit LiquidityRemoved(0, lp, 1 ether, 0, 0, true);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(
            0, uint256(lpPosition.liquidityBalance).wadMul(portionToRemove), [uint256(0), uint256(0)], proposedAmount, 0
        );
        vm.stopPrank();

        LibPerpetual.GlobalPosition memory globalPositionAfter = perpetual.getGlobalPosition();

        // check balances
        assertApproxEqAbs(globalPositionAfter.totalQuoteProvided, minTradeAmount, 1e4);
    }

    function testFuzz_CanRemoveLiquidityThenDeleteLPPosition(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provide base liquidity
        _dealAndProvideLiquidity(lp2, tradeAmount * 2);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // grab initial balances
        LibPerpetual.LiquidityProviderPosition memory lpPosition = perpetual.getLpPosition(lp);
        uint256[2] memory tokensRemoved =
            viewer.getExpectedVirtualTokenAmountsFromLpTokenAmount(0, lp, lpPosition.liquidityBalance);
        LibPerpetual.GlobalPosition memory globalPositionBefore = perpetual.getGlobalPosition();

        // withdraw
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp, 1 ether, 100, [uint256(0), uint256(0)], 0);
        vm.expectEmit(true, true, true, false);
        emit LiquidityRemoved(0, lp, 1 ether, 0, 0, true);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(0, lpPosition.liquidityBalance, [uint256(0), uint256(0)], proposedAmount, 0);
        vm.stopPrank();

        LibPerpetual.GlobalPosition memory globalPositionAfter = perpetual.getGlobalPosition();
        LibPerpetual.LiquidityProviderPosition memory lpPositionAfter = perpetual.getLpPosition(lp);

        // check balances
        assertEq(globalPositionAfter.totalQuoteProvided, globalPositionBefore.totalQuoteProvided - tokensRemoved[0]);
        assertEq(globalPositionAfter.totalBaseProvided, globalPositionBefore.totalBaseProvided - tokensRemoved[1]);

        // check lp position
        assertEq(lpPositionAfter.liquidityBalance, 0);
        assertEq(lpPositionAfter.cumFundingPerLpToken, 0);
        assertEq(lpPositionAfter.openNotional, 0);
        assertEq(lpPositionAfter.positionSize, 0);
    }

    function testFuzz_CanRemoveLiquidityPartially(
        uint256 tradeAmount,
        uint128 globalTradingFeesBeforeWithdrawal,
        int128 cumFundingPerLpToken,
        uint256 portionToRemove
    ) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 10, maxTradeAmount);
        globalTradingFeesBeforeWithdrawal = uint128(bound(globalTradingFeesBeforeWithdrawal, 1, 1e18));
        portionToRemove = bound(portionToRemove, 0.1 ether, 0.75 ether);

        // provide liquidity with two accounts
        _dealAndProvideLiquidity(lp, tradeAmount / 5);
        _dealAndProvideLiquidity(lp2, tradeAmount);

        // set random global trading fees
        perpetual.__TestPerpetual__setGlobalPositionTradingFees(globalTradingFeesBeforeWithdrawal);
        // set random cumulative funding per lp token
        perpetual.__TestPerpetual__setGlobalPositionCumFundingPerLpToken(
            uint64(block.timestamp - 100), cumFundingPerLpToken
        );

        LibPerpetual.LiquidityProviderPosition memory initialLpPosition = perpetual.getLpPosition(lp2);
        assertEq(
            perpetual.getLpTradingFees(lp2),
            uint256(initialLpPosition.liquidityBalance).wadMul(uint256(globalTradingFeesBeforeWithdrawal))
        );

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // remove liquidity as lp2
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp2, portionToRemove, 100, [uint256(0), uint256(0)], 0);
        vm.startPrank(lp2);
        clearingHouse.removeLiquidity(
            0,
            uint128(uint256(initialLpPosition.liquidityBalance).wadMul(portionToRemove)),
            [uint256(0), uint256(0)],
            proposedAmount,
            0
        );
        vm.stopPrank();

        // check lp position
        LibPerpetual.LiquidityProviderPosition memory lpPositionAfter = perpetual.getLpPosition(lp2);

        assertEq(
            lpPositionAfter.liquidityBalance,
            initialLpPosition.liquidityBalance
                - uint128(uint256(initialLpPosition.liquidityBalance).wadMul(portionToRemove))
        );
        assertEq(lpPositionAfter.totalTradingFeesGrowth, globalTradingFeesBeforeWithdrawal);
    }

    function testFuzz_LPImpermanentLoss(uint256 tradeAmount, bool increasePrice) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provide liquidity with two accounts
        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndProvideLiquidity(lp2, tradeAmount);

        // grab before values
        uint256 lpBalanceBeforeInQuote = vault.getBalance(lp2, 0).toUint256();
        uint256 lpBalanceBeforeInBase = lpBalanceBeforeInQuote.wadDiv(perpetual.marketPrice());

        // manipulate market price
        perpetual.__TestPerpetual__manipulate_market(
            increasePrice ? 0 : 1,
            increasePrice ? 1 : 0,
            increasePrice ? (tradeAmount / 2) : (tradeAmount / 2).wadDiv(perpetual.indexPrice().toUint256())
        );
        perpetual.__TestPerpetual__setTWAP(
            uint256(perpetual.marketPrice()).toInt256().toInt128(), perpetual.oracleTwap()
        );

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // remove liquidity as lp2
        uint256 liquidityBalance = perpetual.getLpPosition(lp2).liquidityBalance;
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp2, 1 ether, 100, [uint256(0), uint256(0)], 0);
        vm.startPrank(lp2);
        clearingHouse.removeLiquidity(0, liquidityBalance, [uint256(0), uint256(0)], proposedAmount, 0);
        vm.stopPrank();

        // check lp position
        LibPerpetual.LiquidityProviderPosition memory lpPositionAfter = perpetual.getLpPosition(lp2);
        assertEq(lpPositionAfter.liquidityBalance, 0);
        assertEq(lpPositionAfter.positionSize, 0);
        assertEq(lpPositionAfter.cumFundingPerLpToken, 0);
        assertEq(lpPositionAfter.openNotional, 0);

        // check quote profit
        uint256 lpBalanceAfterInQuote = vault.getBalance(lp2, 0).toUint256();
        if (increasePrice) {
            // TODO: Why does this not hold?
            /* assertGt(lpBalanceAfterInQuote, lpBalanceBeforeInQuote); */
        } else {
            assertLt(lpBalanceAfterInQuote, lpBalanceBeforeInQuote);
        }

        // check base profit
        uint256 lpBalanceAfterInBase = lpBalanceAfterInQuote.wadDiv(perpetual.marketPrice());
        if (increasePrice) {
            assertLt(lpBalanceAfterInBase, lpBalanceBeforeInBase);
        } else {
            assertGt(lpBalanceAfterInBase, lpBalanceBeforeInBase);
        }
    }

    function testFuzz_ShouldRevertWhenNotEnoughLiquidityTokensAreMinted(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provideLiquidity
        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(lp2, tradeAmount);

        // calc expected token amounts
        uint256[2] memory providedAmounts =
            [tradeAmount / 2, (tradeAmount / 2).wadDiv(perpetual.indexPrice().toUint256())];
        uint256 snapshotId = vm.snapshot();
        vm.startPrank(lp2);
        clearingHouse.provideLiquidity(0, providedAmounts, 0);
        vm.stopPrank();
        uint256 expectedLpTokens = perpetual.getLpPosition(lp2).liquidityBalance;
        vm.revertTo(snapshotId);

        // expect revert if minAmount is larger than expected amount
        vm.expectRevert(abi.encodePacked("Slippage"));
        vm.startPrank(lp2);
        clearingHouse.provideLiquidity(0, providedAmounts, expectedLpTokens + 1);
        vm.stopPrank();

        // should pass with expected amount
        vm.startPrank(lp2);
        clearingHouse.provideLiquidity(0, providedAmounts, expectedLpTokens);
        vm.stopPrank();
    }

    function testFuzz_ShouldRevertWhenNotEnoughVirtualTokensAreReleased(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provideLiquidity
        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndProvideLiquidity(lp2, tradeAmount);

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // calc expected token amounts
        LibPerpetual.LiquidityProviderPosition memory lpPosition = perpetual.getLpPosition(lp2);
        LibPerpetual.GlobalPosition memory globalPosition = perpetual.getGlobalPosition();
        (uint256 withdrawnQuoteTokensExFees, uint256 withdrawnBaseTokensExFees) =
            _getTokensToWithdraw(globalPosition, lpPosition);

        // should revert if expected base amount is too large
        vm.expectRevert();
        vm.startPrank(lp2);
        clearingHouse.removeLiquidity(
            0, lpPosition.liquidityBalance, [withdrawnQuoteTokensExFees + 1, withdrawnBaseTokensExFees], 0, 0
        );
        vm.stopPrank();

        // should revert if expected quote amount is too large
        vm.expectRevert();
        vm.startPrank(lp2);
        clearingHouse.removeLiquidity(
            0, lpPosition.liquidityBalance, [withdrawnQuoteTokensExFees, withdrawnBaseTokensExFees + 1], 0, 0
        );
        vm.stopPrank();

        // should succeed with correct base and quote amounts
        uint256 proposedAmount =
            viewer.getLpProposedAmount(0, lp2, 1 ether, 100, [withdrawnQuoteTokensExFees, withdrawnBaseTokensExFees], 0);
        vm.expectEmit(true, true, true, false, address(clearingHouse));
        emit LiquidityRemoved(0, lp2, 1 ether, 0, 0, true);
        vm.startPrank(lp2);
        clearingHouse.removeLiquidity(
            0, lpPosition.liquidityBalance, [withdrawnQuoteTokensExFees, withdrawnBaseTokensExFees], proposedAmount, 0
        );
        vm.stopPrank();
    }

    function testFuzz_CorrectlyCalculatesProfitOfLPs(
        uint256 tradeAmount,
        uint256 durationPassed,
        uint128 globalTradingFeesBeforeWithdrawal
    ) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        globalTradingFeesBeforeWithdrawal = uint128(bound(globalTradingFeesBeforeWithdrawal, 1, 1e18));
        durationPassed =
            bound(durationPassed, 1, vBase.heartBeat() - (block.timestamp - vBaseLastUpdate) - perpetual.lockPeriod());

        // provide base liquidity amount
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // gather initial values
        _dealAndProvideLiquidity(lp2, tradeAmount);
        int256 balanceBefore = vault.getBalance(lp2, 0);

        // set some trading fees
        perpetual.__TestPerpetual__setGlobalPositionTradingFees(globalTradingFeesBeforeWithdrawal);

        // skip the lock period and some time
        vm.warp(block.timestamp + perpetual.lockPeriod() + durationPassed);

        // calculate expected profit
        LibPerpetual.LiquidityProviderPosition memory lpPosition = perpetual.getLpPosition(lp2);
        int256 eProfit = _getLpProfit(lp2);
        int256 globalPositionCumFundingPerLpToken = perpetual.getGlobalPosition().cumFundingPerLpToken;
        int256 eFunding = int256(globalPositionCumFundingPerLpToken - lpPosition.cumFundingPerLpToken).wadMul(
            uint256(lpPosition.liquidityBalance).toInt256()
        );

        // remove liquidity
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp2, 1 ether, 100, [uint256(0), uint256(0)], 0);
        vm.startPrank(lp2);
        clearingHouse.removeLiquidity(0, lpPosition.liquidityBalance, [uint256(0), uint256(0)], proposedAmount, 0);
        vm.stopPrank();

        // check profit
        int256 balanceAfter = vault.getBalance(lp2, 0);
        assertEq(balanceAfter, balanceBefore + eProfit + eFunding);
    }

    function testFuzz_ShouldEmitProvideLiquidityEventInCryptoSwap(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndDeposit(lp, tradeAmount);

        uint256 quoteAmount = tradeAmount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.expectEmit(true, true, true, true, address(cryptoSwap));
        emit AddLiquidity(address(perpetual), [quoteAmount, baseAmount], 0, 0);
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function testFuzz_CurveTakesZeroAdminFees(uint256 tradeAmount, bool long) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // deposit some liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // make a trade
        _dealAndDeposit(trader, tradeAmount);
        uint256 indexPrice = perpetual.indexPrice().toUint256();
        vm.startPrank(trader);
        clearingHouse.changePosition(
            0,
            long ? tradeAmount : tradeAmount.wadDiv(indexPrice),
            0,
            long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short
        );
        vm.stopPrank();

        // get profit before
        address feeReceiver = factory.fee_receiver();
        uint256 virtualPriceBefore = cryptoSwap.virtual_price();
        uint256 xpcProfitBefore = cryptoSwap.xcp_profit();
        assertGt(xpcProfitBefore, 0);
        assertEq(lpToken.balanceOf(feeReceiver), 0);

        // zero admin fees should be claimed
        cryptoSwap.claim_admin_fees();
        assertEq(cryptoSwap.xcp_profit(), cryptoSwap.xcp_profit_a());
        assertEq(cryptoSwap.virtual_price(), virtualPriceBefore);
        assertEq(cryptoSwap.xcp_profit(), xpcProfitBefore);
        assertEq(lpToken.balanceOf(feeReceiver), 0);
    }

    function testFuzz_removeLiquiditySwapAlwaysReverts(
        address account,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts,
        bytes calldata func
    ) public {
        vm.expectRevert();
        perpetual.removeLiquiditySwap(account, liquidityAmountToRemove, minVTokenAmounts, func);
    }

    function testFuzz_ShouldAccountLiquidityProvidedWithUAandUSDC(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        // provide liquidity with UA
        _dealAndProvideLiquidity(lp, tradeAmount);
        LibPerpetual.LiquidityProviderPosition memory lpPositionAfterFirstDeposit = viewer.getLpPosition(0, lp);

        // deal with USDC and deposit some more liquidity
        _dealUSDCAndDeposit(lp, tradeAmount);
        uint256 indexPrice = perpetual.indexPrice().toUint256();
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [tradeAmount / 2, (tradeAmount / 2).wadDiv(indexPrice)], 0);
        vm.stopPrank();

        LibPerpetual.LiquidityProviderPosition memory lpPositionAfterSecondDeposit = viewer.getLpPosition(0, lp);

        assertGt(lpPositionAfterSecondDeposit.liquidityBalance, lpPositionAfterFirstDeposit.liquidityBalance);
    }

    function testFuzz_LPShouldBeAbleToWithdrawOneCollateralWithoutAffectingEntirePosition(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 3);

        // provide liquidity with UA
        _dealAndProvideLiquidity(lp2, tradeAmount);
        _dealAndProvideLiquidity(lp, tradeAmount);

        // deal with USDC and deposit some more liquidity
        _dealUSDCAndDeposit(lp, tradeAmount);
        uint256 indexPrice = perpetual.indexPrice().toUint256();
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(0, [tradeAmount / 2, (tradeAmount / 2).wadDiv(indexPrice)], 0);
        vm.stopPrank();

        // grab intermediate values
        LibPerpetual.LiquidityProviderPosition memory lpPositionBefore = perpetual.getLpPosition(lp);

        // skip the lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // remove half of the liquidity
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp, 5e17, 100, [uint256(0), uint256(0)], 0);
        vm.expectEmit(true, true, true, false);
        emit LiquidityRemoved(0, lp, 5e17, 0, 0, true);
        vm.startPrank(lp);
        clearingHouse.removeLiquidity(
            0, lpPositionBefore.liquidityBalance / 2, [uint256(0), uint256(0)], proposedAmount, 0
        );
        vm.stopPrank();

        // check lp position
        LibPerpetual.LiquidityProviderPosition memory lpPositionAfter = perpetual.getLpPosition(lp);
        assertApproxEqRel((lpPositionBefore.liquidityBalance / 2), lpPositionAfter.liquidityBalance, 1);

        int256 lpReserveValueAfter = viewer.getReserveValue(lp, false);
        int256 lpUABalanceAfter = viewer.getBalance(lp, 0);
        int256 lpUSDCBalanceAfter = viewer.getBalance(lp, 1);

        int256 profit = lpUABalanceAfter + lpUSDCBalanceAfter.wadMul(oracle.getPrice(address(usdc), lpUSDCBalanceAfter))
            - (tradeAmount * 2).toInt256();
        assertEq(lpReserveValueAfter, (tradeAmount * 2).toInt256() + profit);
    }

    function testFuzz_LPsShouldPayAndReceiveFundingOfTraders(uint256 liquidityAmount, uint256 tradeAmount, bool long)
        public
    {
        liquidityAmount = bound(liquidityAmount, minTradeAmount * 8, maxTradeAmount / 2);
        tradeAmount = bound(liquidityAmount, minTradeAmount * 4, liquidityAmount / 2);

        // provide liquidity
        _dealAndProvideLiquidity(lp, liquidityAmount);

        // make a trade
        _dealAndDeposit(trader, tradeAmount);
        uint256 indexPrice = perpetual.indexPrice().toUint256();
        vm.startPrank(trader);
        emit log_named_uint("tradeAmount", tradeAmount);
        clearingHouse.changePosition(
            0,
            long ? tradeAmount / 2 : (tradeAmount / 2).wadMul(indexPrice),
            0,
            long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short
        );
        vm.stopPrank();

        // skip twap frequency
        vm.warp(block.timestamp + perpetual.twapFrequency());

        // update global state
        perpetual.updateGlobalState();

        // global checks
        LibPerpetual.GlobalPosition memory globalPosition = perpetual.getGlobalPosition();
        assertTrue(globalPosition.cumFundingRate != 0);
        assertTrue(globalPosition.cumFundingPerLpToken != 0);

        if (long) {
            assertGt(
                uint256(globalPosition.traderLongs).toInt256() - uint256(globalPosition.traderShorts).toInt256(), 0
            );
        } else {
            assertLt(
                uint256(globalPosition.traderLongs).toInt256() - uint256(globalPosition.traderShorts).toInt256(), 0
            );
        }

        int256 lpFunding = viewer.getLpFundingPayments(0, lp);
        assertTrue(lpFunding != 0);
        int256 traderFunding = viewer.getTraderFundingPayments(0, trader);
        assertTrue(traderFunding != 0);
        assertLt(traderFunding, 1);
    }
}
