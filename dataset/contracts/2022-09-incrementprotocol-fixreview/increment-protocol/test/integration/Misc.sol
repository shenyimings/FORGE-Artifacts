// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";
import {TestRewardContract} from "../mocks/TestRewardContract.sol";

// interfaces
import "../../contracts/interfaces/IClearingHouse.sol";
import "../../contracts/interfaces/IVBase.sol";

// libraries
import "../../contracts/lib/LibMath.sol";
import "../../contracts/lib/LibReserve.sol";
import "../../contracts/lib/LibPerpetual.sol";
import "../../lib/forge-std/src/StdError.sol";

contract Liquidation is Deployment {
    // events
    event DustGenerated(int256 vBaseAmount);
    event RewardContractChanged(IRewardContract newRewardContract);

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

    function _dealAndDeposit(address addr, uint256 amount) internal {
        deal(address(ua), addr, amount);

        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        clearingHouse.deposit(amount, ua);
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

    function setUp() public virtual override {
        super.setUp();
        maxTradeAmount = perpetual.maxPosition();
        minTradeAmount = clearingHouse.minPositiveOpenNotional();
    }

    function testFuzz_ShouldEstimateLpTokensReturnedAgainstVirtualTokens(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount, maxTradeAmount);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // get estimated amount
        uint256[2] memory amounts = [tradeAmount, (tradeAmount).wadDiv(perpetual.indexPrice().toUint256())];
        uint256 estimatedLpTokens = viewer.getExpectedLpTokenAmount(0, amounts);

        // provide and get amount
        _dealAndProvideLiquidity(lp2, tradeAmount * 2);
        uint256 liquidityBalance = viewer.getLpPosition(0, lp2).liquidityBalance;

        assertApproxEqAbs(liquidityBalance, estimatedLpTokens, 1);
    }

    function testFuzz_CorrectlyEstimatingMinAmountsShouldProtectUserFromUndesirableReturnedAmounts(
        uint256 tradeAmount,
        bool long
    ) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 4, maxTradeAmount);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);
        _dealAndProvideLiquidity(lp2, tradeAmount * 2);

        // skip lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // calc min amounts
        uint256 liquidityBalance = viewer.getLpPosition(0, lp2).liquidityBalance;
        uint256[2] memory estimatedMinVTokenAmounts =
            viewer.getExpectedVirtualTokenAmountsFromLpTokenAmount(0, lp2, liquidityBalance);
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp2, 1 ether, 100, estimatedMinVTokenAmounts, 0);

        // change market price
        _dealAndDeposit(trader, tradeAmount);
        uint256 indexPrice = perpetual.indexPrice().toUint256();
        vm.startPrank(trader);
        clearingHouse.changePosition(
            0,
            long ? (tradeAmount / 2) : (tradeAmount / 2).wadDiv(indexPrice),
            0,
            long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short
        );
        vm.stopPrank();

        // attempt to remove should fail
        vm.expectRevert();
        vm.startPrank(lp2);
        clearingHouse.removeLiquidity(0, liquidityBalance, estimatedMinVTokenAmounts, proposedAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_CanCalculateUnrealizedPnLIfNotTrader(address addr) public view {
        viewer.getTraderUnrealizedPnL(0, addr);
    }

    function testFuzz_CanCalculateUnrealizedPnLOfTrader(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount);

        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // create position
        _dealAndDeposit(trader, tradeAmount * 2);
        uint256 indexPrice = perpetual.indexPrice().toUint256();
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount.wadDiv(indexPrice), 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        // calculate unrealized PnL
        LibPerpetual.TraderPosition memory traderPosition = viewer.getTraderPosition(0, trader);
        int256 quoteProceeds = perpetual.indexPrice().wadMul(int256(traderPosition.positionSize));
        uint256 feesInWad = cryptoSwap.out_fee() * 1e8;
        uint256 tradingFees = quoteProceeds.abs().toUint256().wadMul(feesInWad);
        int256 estimatedPnL = int256(traderPosition.openNotional) + quoteProceeds - tradingFees.toInt256();

        assertEq(viewer.getTraderUnrealizedPnL(0, trader), estimatedPnL);
    }

    function testFuzz_CanCalculateFundingPaymentsIfNotTrader(address addr) public view {
        viewer.getFundingPayments(0, addr);
    }

    function testFuzz_CannotCalculateUnrealizedPnLOfTraderWithLpFunction(address addr) public view {
        viewer.getLpUnrealizedPnL(0, addr);
    }

    function testFuzz_CanCalculateUnrealizedPnLOfLp(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount);

        // calc estimated pnl
        LibPerpetual.TraderPosition memory lpPositionAfterWithdrawal = viewer.getLpPositionAfterWithdrawal(0, lp);
        int256 quoteProceeds = int256(lpPositionAfterWithdrawal.positionSize).wadMul(perpetual.indexPrice());
        int256 tradingFees = quoteProceeds.abs().wadMul(int256(cryptoSwap.out_fee() * 1e8));
        int256 estimatedPnL = int256(lpPositionAfterWithdrawal.openNotional) + quoteProceeds - tradingFees;

        assertEq(perpetual.getLpUnrealizedPnL(lp), estimatedPnL);
    }

    function testFuzz_CanCalculateFundingPaymentsIfNotLp(address addr) public view {
        viewer.getLpFundingPayments(0, addr);
    }

    function testFuzz_TradesGenerateCorrectDust(uint256 tradeAmount, int256 amountDiff, bool long) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount);
        amountDiff = bound(amountDiff, -10, 10);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // create trader position
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

        // close position and get dust
        int256 positionSize = perpetual.getTraderPosition(trader).positionSize;
        int256 proposedAmount = viewer.getTraderProposedAmount(0, trader, 1 ether, 100, 0).toInt256()
            + (positionSize > 0 ? amountDiff : -amountDiff);
        int256 baseDust = positionSize > 0
            ? -amountDiff
            : curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, 0, 1, proposedAmount.toUint256()).toInt256() + positionSize;

        //  close position
        vm.expectEmit(true, true, true, true);
        emit DustGenerated(baseDust);
        vm.startPrank(trader);
        clearingHouse.changePosition(
            0, proposedAmount.toUint256(), 0, long ? LibPerpetual.Side.Short : LibPerpetual.Side.Long
        );
        vm.stopPrank();

        // check dust
        assertTrue(!viewer.isTraderPositionOpen(0, trader));
        assertEq(viewer.getBaseDust(0), perpetual.getTraderPosition(address(clearingHouse)).positionSize);
        assertEq(viewer.getBaseDust(0), baseDust);
    }

    function testFuzz_LargeDustGetsReverted(uint256 tradeAmount, bool long, bool aboveTarget) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 4, maxTradeAmount / 2);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 6);

        // create trader position
        _dealAndDeposit(trader, tradeAmount);
        uint256 indexPrice = perpetual.indexPrice().toUint256();
        vm.startPrank(trader);
        clearingHouse.changePosition(
            0,
            long ? (tradeAmount / 2) : (tradeAmount / 2).wadDiv(indexPrice),
            0,
            long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short
        );
        vm.stopPrank();

        // close position and get dust
        LibPerpetual.TraderPosition memory traderPosition = viewer.getTraderPosition(0, trader);
        int256 vQuoteDustThreshold = 1e17;
        int256 vBaseDustThreshold = vQuoteDustThreshold.wadDiv(perpetual.indexPrice()) + 1e7;

        // get proposedAmount with manipulated position
        perpetual.__TestPerpetual__setTraderPosition(
            trader,
            traderPosition.openNotional,
            (int256(traderPosition.positionSize) + (aboveTarget ? vBaseDustThreshold : -vBaseDustThreshold)).toInt128(),
            traderPosition.cumFundingRate
        );
        uint256 proposedAmountOffTarget = viewer.getTraderProposedAmount(0, trader, 1 ether, 100, 0);

        // reset position
        perpetual.__TestPerpetual__setTraderPosition(
            trader, traderPosition.openNotional, traderPosition.positionSize, traderPosition.cumFundingRate
        );

        // should fail if exceeds dust threshold
        vm.expectRevert();
        vm.startPrank(trader);
        clearingHouse.changePosition(
            0, proposedAmountOffTarget, 0, long ? LibPerpetual.Side.Short : LibPerpetual.Side.Long
        );
        vm.stopPrank();
    }

    function testFuzz_LpActionsShouldGenerateDust(uint256 tradeAmount, int256 dustAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount);
        dustAmount = bound(dustAmount, -10, 10);
        vm.assume(dustAmount != 0);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // create trader position
        _dealAndDeposit(trader, tradeAmount);
        uint256 indexPrice = perpetual.indexPrice().toUint256();
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount.wadDiv(indexPrice), 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        // provide liquidity as lp2
        _dealAndProvideLiquidity(lp2, tradeAmount * 2);

        // skip lock period
        vm.warp(block.timestamp + perpetual.lockPeriod());

        // get proposedAmount
        uint256 proposedAmount = viewer.getLpProposedAmount(0, lp2, 1 ether, 100, [uint256(0), uint256(0)], 0);
        LibPerpetual.LiquidityProviderPosition memory lpPosition = viewer.getLpPosition(0, lp2);

        // withdraw liquidity
        vm.expectEmit(true, true, true, true);
        emit DustGenerated(-dustAmount);
        vm.startPrank(lp2);
        clearingHouse.removeLiquidity(
            0,
            lpPosition.liquidityBalance,
            [uint256(0), uint256(0)],
            (proposedAmount.toInt256() + dustAmount).toUint256(),
            0
        );
        vm.stopPrank();
    }

    function test_CanAddRewardContract() public {
        TestRewardContract rewardContract = new TestRewardContract(clearingHouse, usdc);

        vm.expectEmit(true, true, true, true);
        emit RewardContractChanged(rewardContract);
        clearingHouse.addRewardContract(rewardContract);
    }

    function test_FailsToAddRewardContractZeroAddress() public {
        vm.expectRevert(IClearingHouse.ClearingHouse_ZeroAddress.selector);
        clearingHouse.addRewardContract(TestRewardContract(address(0)));
    }

    function testFuzz_CanStoreLiquidityPositionInRewardContract(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount);

        // add reward contract
        TestRewardContract rewardContract = new TestRewardContract(clearingHouse, usdc);
        clearingHouse.addRewardContract(rewardContract);

        // provide liquidity
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        assertEq(rewardContract.balanceOf(lp), tradeAmount);
    }

    function test_FailsToGetIndexPriceIfSequencerDown() public {
        sequencerUptimeFeed.updateRoundData(0, 1, 0, 0);
        vm.expectRevert(IVBase.VBase_SequencerDown.selector);
        perpetual.indexPrice();
    }

    function testFuzz_FailsToGetIndexPriceDuringGracePeriod(uint256 duration) public {
        duration = bound(duration, 0, vBase.gracePeriod());

        // update sequencer uptime feed
        sequencerUptimeFeed.updateAnswer(0);

        // skip time (within gracePeriod)
        vm.warp(block.timestamp + duration);

        vm.expectRevert(IVBase.VBase_GracePeriodNotOver.selector);
        perpetual.indexPrice();
    }

    function testFuzz_FailsToGetIndexPriceIfNoUpdatesPastHeartBeat(uint256 duration) public {
        duration = bound(duration, vBase.heartBeat(), type(uint64).max);

        // update sequencer uptime feed
        vm.mockCall(
            address(baseOracle),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(1, 1, 1, 1, 1)
        );

        // skip time (within gracePeriod)
        vm.warp(block.timestamp + duration);

        vm.expectRevert(IVBase.VBase_DataNotFresh.selector);
        perpetual.indexPrice();
    }

    function testFuzz_FailsToGetIndexPriceWithInvalidTimestamp() public {
        // update sequencer uptime feed
        vm.mockCall(
            address(baseOracle),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, 0, 0, 0, 0)
        );

        vm.expectRevert(IVBase.VBase_InvalidRoundTimestamp.selector);
        perpetual.indexPrice();
    }

    function testFuzz_FailsToGetIndexPriceWithInvalidRoundPrice() public {
        // update sequencer uptime feed
        vm.mockCall(
            address(baseOracle),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, 0, 0, block.timestamp, 0)
        );

        vm.expectRevert(IVBase.VBase_InvalidRoundPrice.selector);
        perpetual.indexPrice();
    }
}
