// SPDX-License-Identifier: AGPL-3
pragma solidity 0.8.16;

// contracts
import {Perpetual} from "../../contracts/Perpetual.sol";

// interfaces
import {ICryptoSwap} from "../../contracts/interfaces/ICryptoSwap.sol";
import {IVBase} from "../../contracts/interfaces/IVBase.sol";
import {IVQuote} from "../../contracts/interfaces/IVQuote.sol";
import {IClearingHouse} from "../../contracts/interfaces/IClearingHouse.sol";
import {ICurveCryptoViews} from "../../contracts/interfaces/ICurveCryptoViews.sol";
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// libraries
import {LibPerpetual} from "../../contracts/lib/LibPerpetual.sol";
import {LibMath} from "../../contracts/lib/LibMath.sol";

/// @notice Emitted when the given token index is gt 1
error TestPerpetual__InvalidTokenIndex(uint256 idx);

/// @notice Emitted when the initial buy amount is less than the target position size
error TestPerpetual__BuyAmountTooSmall();

/*
 * TestPerpetual includes some setter functions to edit part of
 * the internal state of Perpetual which aren't exposed otherwise.
 */
contract TestPerpetual is Perpetual {
    using LibMath for int256;
    using LibMath for uint256;

    // emit event which can be cached in tests
    event SwapForExact(uint256 boughtVBaseTokens, uint256 additionalTokens);

    constructor(
        IVBase _vBase,
        IVQuote _vQuote,
        ICryptoSwap _market,
        IClearingHouse _clearingHouse,
        ICurveCryptoViews _views,
        bool _isTradingExpansionAllowed,
        PerpetualParams memory _params
    ) Perpetual(_vBase, _vQuote, _market, _clearingHouse, _views, _isTradingExpansionAllowed, _params) {}

    // simplified setter for funding rate manipulation
    function __TestPerpetual__setGlobalPositionFundingRate(uint64 timeOfLastTrade, int128 cumFundingRate) external {
        globalPosition.timeOfLastTrade = timeOfLastTrade;
        globalPosition.cumFundingRate = cumFundingRate;
    }

    // simplified setter for lp funding rate manipulation
    function __TestPerpetual__setGlobalPositionCumFundingPerLpToken(uint64 timeOfLastTrade, int128 cumFundingPerLpToken)
        external
    {
        globalPosition.timeOfLastTrade = timeOfLastTrade;
        globalPosition.cumFundingPerLpToken = cumFundingPerLpToken;
    }

    // simplified setter for trading fees manipulation
    function __TestPerpetual__setGlobalPositionTradingFees(uint128 totalTradingFeesGrowth) external {
        globalPosition.totalTradingFeesGrowth = totalTradingFeesGrowth;
    }

    function __TestPerpetual__setLpPosition(
        address lp,
        int128 openNotional,
        int128 positionSize,
        uint128 liquidityBalance,
        uint64 depositTime,
        uint128 totalTradingFeesGrowth,
        uint128 totalBaseFeesGrowth,
        uint128 totalQuoteFeesGrowth,
        int128 cumFundingPerLpToken
    ) external {
        lpPosition[lp] = LibPerpetual.LiquidityProviderPosition({
            openNotional: openNotional,
            positionSize: positionSize,
            liquidityBalance: liquidityBalance,
            depositTime: depositTime,
            totalTradingFeesGrowth: totalTradingFeesGrowth,
            totalBaseFeesGrowth: totalBaseFeesGrowth,
            totalQuoteFeesGrowth: totalQuoteFeesGrowth,
            cumFundingPerLpToken: cumFundingPerLpToken
        });
    }

    function __TestPerpetual__setTraderPosition(
        address trader,
        int128 openNotional,
        int128 positionSize,
        int128 cumFundingRate
    ) external {
        traderPosition[trader] = LibPerpetual.TraderPosition({
            openNotional: openNotional,
            positionSize: positionSize,
            cumFundingRate: cumFundingRate
        });
        require((positionSize > 0) != (openNotional > 0), "invalid position");
        if (positionSize >= 0) {
            globalPosition.traderLongs += uint256(int256(positionSize)).toUint128();
        } else {
            globalPosition.traderShorts += uint256(int256(-positionSize)).toUint128();
        }
    }

    function __TestPerpetual__manipulate_market(uint256 tokenToSell, uint256 tokenToBuy, uint256 amountToSell)
        external
        returns (uint256)
    {
        if (tokenToSell >= 2) revert TestPerpetual__InvalidTokenIndex(tokenToSell);
        if (tokenToBuy >= 2) revert TestPerpetual__InvalidTokenIndex(tokenToBuy);

        if (tokenToSell == VQUOTE_INDEX) {
            vQuote.mint(amountToSell);
        } else {
            vBase.mint(amountToSell);
        }

        return market.exchange(tokenToSell, tokenToBuy, amountToSell, 0);
    }

    function __TestPerpetual__swap_for_exact(uint256 proposedAmount, uint256 targetPositionSize) external {
        // mint tokens
        vQuote.mint(proposedAmount);

        (uint256 boughtVBaseTokens,) = _quoteForBase(proposedAmount, 0);

        if (boughtVBaseTokens < targetPositionSize) revert TestPerpetual__BuyAmountTooSmall();

        uint256 baseRemaining = boughtVBaseTokens - targetPositionSize;

        emit SwapForExact(boughtVBaseTokens, baseRemaining);
    }

    function __TestPerpetual__updateFunding() external {
        _updateFundingRate();
    }

    function __TestPerpetual__updateTwap() external {
        _updateTwap();
    }

    function __TestPerpetual__setTWAP(int128 _marketTwap, int128 _oracleTwap) external {
        marketTwap = _marketTwap;
        oracleTwap = _oracleTwap;
    }

    function __TestPerpetual__updateCurrentBlockTradeAmount(uint256 quoteAmount) external {
        _updateCurrentBlockTradeAmount(quoteAmount);
    }

    function __TestPerpetual__resetCurrentBlockTradeAmount() external {
        _resetCurrentBlockTradeAmount();
    }

    function __TestPerpetual__checkBlockTradeAmount() external view returns (bool) {
        return _checkBlockTradeAmount();
    }

    /* unprotected version of `settleTrader' without updating the global state*/
    function __TestPerpetual__settleTraderNoUpdate(address account) external returns (int256 fundingPayments) {
        LibPerpetual.TraderPosition storage trader = traderPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        // _updateGlobalState();

        if (!_isTraderPositionOpen(trader)) {
            return 0;
        }

        fundingPayments = _getTraderFundingPayments(
            trader.positionSize >= 0, trader.cumFundingRate, globalP.cumFundingRate, int256(trader.positionSize).abs()
        );

        emit FundingPaid(account, fundingPayments, globalP.cumFundingRate, trader.cumFundingRate, true);

        trader.cumFundingRate = globalP.cumFundingRate;

        return fundingPayments;
    }

    function __TestPerpetual__settleTraderWithUpdate(address account) external returns (int256 fundingPayments) {
        LibPerpetual.TraderPosition storage trader = traderPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        _updateGlobalState();

        if (!_isTraderPositionOpen(trader)) {
            return 0;
        }

        fundingPayments = _getTraderFundingPayments(
            trader.positionSize >= 0, trader.cumFundingRate, globalP.cumFundingRate, int256(trader.positionSize).abs()
        );

        emit FundingPaid(account, fundingPayments, globalP.cumFundingRate, trader.cumFundingRate, true);

        trader.cumFundingRate = globalP.cumFundingRate;

        return fundingPayments;
    }

    /* unprotected version of `settleLp' without updating the global state*/
    function __TestPerpetual__settleLpNoUpdate(address account) external returns (int256 fundingPayments) {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        // _updateGlobalState();

        if (!_isLpPositionOpen(lp)) {
            return 0;
        }

        // settle lp funding rate
        fundingPayments =
            _getLpFundingPayments(lp.cumFundingPerLpToken, globalP.cumFundingPerLpToken, lp.liquidityBalance);

        emit FundingPaid(account, fundingPayments, globalP.cumFundingPerLpToken, lp.cumFundingPerLpToken, false);

        lp.cumFundingPerLpToken = globalP.cumFundingPerLpToken;

        return fundingPayments;
    }

    function __TestPerpetual__settleLpWithUpdate(address account) external returns (int256 fundingPayments) {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        _updateGlobalState();

        if (!_isLpPositionOpen(lp)) {
            return 0;
        }

        // settle lp funding rate
        fundingPayments =
            _getLpFundingPayments(lp.cumFundingPerLpToken, globalP.cumFundingPerLpToken, lp.liquidityBalance);

        emit FundingPaid(account, fundingPayments, globalP.cumFundingPerLpToken, lp.cumFundingPerLpToken, false);

        lp.cumFundingPerLpToken = globalP.cumFundingPerLpToken;

        return fundingPayments;
    }

    // perform a removal of liquidity and swap in one function call
    function __TestPerpetual__remove_liquidity_swap(
        ICryptoSwap market_,
        ICurveCryptoViews views_,
        IVBase vBase_,
        uint256 liquidityAmountToRemove,
        uint256 globalTotalBaseFeesGrowth,
        uint256 lpTotalBaseFeesGrowth,
        uint256 proposedAmount
    ) public returns (uint256 baseLiquidity, uint256 baseProceeds) {
        baseLiquidity =
            _removeLiquidity(market_, vBase_, liquidityAmountToRemove, globalTotalBaseFeesGrowth, lpTotalBaseFeesGrowth);
        baseProceeds = __TestPerpetual__quoteForBase(proposedAmount, market_, views_);

        return (baseLiquidity, baseProceeds);
    }

    function __TestPerpetual__getWithdrawableTokens(address lpAddress, uint256 liquidityAmountToRemove)
        external
        view
        returns (uint256 quoteTokensExFees, uint256 baseTokensExFees)
    {
        // LP position
        LibPerpetual.LiquidityProviderPosition memory lp = lpPosition[lpAddress];
        uint256 totalLiquidityProvided = getTotalLiquidityProvided();

        (quoteTokensExFees,) = _getVirtualTokensWithdrawnFromCurvePool(
            totalLiquidityProvided,
            liquidityAmountToRemove,
            market.balances(VQUOTE_INDEX),
            lp.totalQuoteFeesGrowth,
            globalPosition.totalQuoteFeesGrowth
        );

        (baseTokensExFees,) = _getVirtualTokensWithdrawnFromCurvePool(
            totalLiquidityProvided,
            liquidityAmountToRemove,
            market.balances(VBASE_INDEX),
            lp.totalBaseFeesGrowth,
            globalPosition.totalBaseFeesGrowth
        );
    }

    // optimized version of _removeLiquidity
    function _removeLiquidity(
        ICryptoSwap market_,
        IVBase vBase_,
        uint256 liquidityAmountToRemove,
        uint256 globalTotalBaseFeesGrowth,
        uint256 lpTotalBaseFeesGrowth
    ) internal returns (uint256 baseAmount) {
        // remove liquidity
        uint256 vBaseBalanceBefore = vBase_.balanceOf(address(this));

        market_.remove_liquidity(liquidityAmountToRemove, [uint256(0), uint256(0)]);

        uint256 baseAmountInclFees = vBase_.balanceOf(address(this)) - vBaseBalanceBefore;

        // remove fee component from quoteAmount
        baseAmount = baseAmountInclFees.wadDiv(1e18 + globalTotalBaseFeesGrowth - lpTotalBaseFeesGrowth);
    }

    // optimized version of _quoteForBase
    function __TestPerpetual__quoteForBase(uint256 quoteAmount, ICryptoSwap _market, ICurveCryptoViews _views)
        internal
        view
        returns (uint256)
    {
        return _views.get_dy_no_fee_deduct(_market, VQUOTE_INDEX, VBASE_INDEX, quoteAmount);
    }

    function __TestPerpetual__setMarket(ICryptoSwap _market) external {
        market = _market;
    }
}
