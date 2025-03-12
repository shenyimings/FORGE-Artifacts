// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// forks of uniswap libraries for solidity^0.8.10
import "../../libraries/uniswap/v3-core/FullMath.sol";
import "../../libraries/uniswap/v3-core/TickMath.sol";

import "../../interfaces/feeds/uniswapv3/IOverlayV1UniswapV3Feed.sol";
import "../OverlayV1Feed.sol";

contract OverlayV1UniswapV3Feed is IOverlayV1UniswapV3Feed, OverlayV1Feed {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint128 internal constant ONE = 1e18; // 18 decimal places for ovl

    address public immutable marketPool;
    address public immutable ovlWethPool;
    address public immutable ovl;

    address public immutable marketToken0;
    address public immutable marketToken1;
    address public immutable ovlWethToken0;
    address public immutable ovlWethToken1;

    address public immutable marketBaseToken;
    address public immutable marketQuoteToken;
    uint128 public immutable marketBaseAmount;

    constructor(
        address _marketPool,
        address _ovlWethPool,
        address _ovl,
        address _marketBaseToken,
        address _marketQuoteToken,
        uint128 _marketBaseAmount,
        uint256 _microWindow,
        uint256 _macroWindow
    ) OverlayV1Feed(_microWindow, _macroWindow) {
        // need WETH in market pool to make reserve conversion from ETH => OVL
        address _marketToken0 = IUniswapV3Pool(_marketPool).token0();
        address _marketToken1 = IUniswapV3Pool(_marketPool).token1();

        require(_marketToken0 == WETH || _marketToken1 == WETH, "OVLV1Feed: marketToken != WETH");
        marketToken0 = _marketToken0;
        marketToken1 = _marketToken1;

        require(
            _marketToken0 == _marketBaseToken || _marketToken1 == _marketBaseToken,
            "OVLV1Feed: marketToken != marketBaseToken"
        );
        require(
            _marketToken0 == _marketQuoteToken || _marketToken1 == _marketQuoteToken,
            "OVLV1Feed: marketToken != marketQuoteToken"
        );
        marketBaseToken = _marketBaseToken;
        marketQuoteToken = _marketQuoteToken;
        marketBaseAmount = _marketBaseAmount;

        // need OVL/WETH pool for ovl vs ETH price to make reserve conversion from ETH => OVL
        address _ovlWethToken0 = IUniswapV3Pool(_ovlWethPool).token0();
        address _ovlWethToken1 = IUniswapV3Pool(_ovlWethPool).token1();

        require(
            _ovlWethToken0 == WETH || _ovlWethToken1 == WETH,
            "OVLV1Feed: ovlWethToken != WETH"
        );
        require(
            _ovlWethToken0 == _ovl || _ovlWethToken1 == _ovl,
            "OVLV1Feed: ovlWethToken != OVL"
        );
        ovlWethToken0 = _ovlWethToken0;
        ovlWethToken1 = _ovlWethToken1;

        marketPool = _marketPool;
        ovlWethPool = _ovlWethPool;
        ovl = _ovl;
    }

    /// @dev fetches TWAP, liquidity data from the univ3 pool oracle
    /// @dev for micro and macro window averaging intervals.
    /// @dev market pool and ovlweth pool have different consult inputs
    /// @dev to minimize accumulator snapshot queries with consult
    function _fetch() internal view virtual override returns (Oracle.Data memory) {
        // cache micro and macro windows for gas savings
        uint256 _microWindow = microWindow;
        uint256 _macroWindow = macroWindow;

        // consult to market pool
        // secondsAgo.length = 4; twaps.length = liqs.length = 3
        (
            uint32[] memory secondsAgos,
            uint32[] memory windows,
            uint256[] memory nowIdxs
        ) = _inputsToConsultMarketPool(_microWindow, _macroWindow);
        (
            int24[] memory arithmeticMeanTicksMarket,
            uint128[] memory harmonicMeanLiquiditiesMarket
        ) = consult(marketPool, secondsAgos, windows, nowIdxs);

        // consult to ovlWeth pool
        // secondsAgo.length = 2; twaps.length = liqs.length = 1
        (
            uint32[] memory secondsAgosOvlWeth,
            uint32[] memory windowsOvlWeth,
            uint256[] memory nowIdxsOvlWeth
        ) = _inputsToConsultOvlWethPool(_microWindow, _macroWindow);
        (int24[] memory arithmeticMeanTicksOvlWeth, ) = consult(
            ovlWethPool,
            secondsAgosOvlWeth,
            windowsOvlWeth,
            nowIdxsOvlWeth
        );
        int24 arithmeticMeanTickOvlWeth = arithmeticMeanTicksOvlWeth[0];

        // in terms of prices, will use for indexes
        //  0: priceOneMacroWindowAgo
        //  1: priceOverMacroWindow
        //  2: priceOverMicroWindow
        uint256[] memory prices = new uint256[](nowIdxs.length);

        // reserve is the reserve in marketPool over micro window
        // needs ovlWeth price over micro to convert into OVL terms from WETH
        uint256 reserve;
        for (uint256 i = 0; i < nowIdxs.length; i++) {
            uint256 price = getQuoteAtTick(
                arithmeticMeanTicksMarket[i],
                marketBaseAmount,
                marketBaseToken,
                marketQuoteToken
            );
            prices[i] = price;

            // if calculating priceOverMicroWindow in this loop,
            // then calculate the reserve as well
            if (i == 2) {
                // TODO: pertaining to `arithmeticMeanTicksOvlWeth[i]`: use micro ovl/weth twap for
                // conversion? (safe?)
                reserve = getReserveInOvl(
                    arithmeticMeanTicksMarket[i],
                    harmonicMeanLiquiditiesMarket[i],
                    arithmeticMeanTickOvlWeth
                );
            }
        }

        return
            Oracle.Data({
                timestamp: block.timestamp,
                microWindow: _microWindow,
                macroWindow: _macroWindow,
                priceOverMicroWindow: prices[2], // secondsAgos = _microWindow
                priceOverMacroWindow: prices[1], // secondsAgos = _macroWindow
                priceOneMacroWindowAgo: prices[0], // secondsAgos = _macroWindow * 2
                reserveOverMicroWindow: reserve,
                hasReserve: true
            });
    }

    /// @dev returns input params needed for call to marketPool consult
    function _inputsToConsultMarketPool(uint256 _microWindow, uint256 _macroWindow)
        private
        pure
        returns (
            uint32[] memory,
            uint32[] memory,
            uint256[] memory
        )
    {
        uint32[] memory secondsAgos = new uint32[](4);
        uint32[] memory windows = new uint32[](3);
        uint256[] memory nowIdxs = new uint256[](3);

        // number of seconds in past for which we want accumulator snapshot
        // for Oracle.Data, need:
        //  1. now (0 s ago)
        //  2. now - microWindow (microWindow seconds ago)
        //  3. now - macroWindow (macroWindow seconds ago)
        //  4. now - 2 * macroWindow (2 * macroWindow seconds ago)
        secondsAgos[0] = uint32(_macroWindow * 2);
        secondsAgos[1] = uint32(_macroWindow);
        secondsAgos[2] = uint32(_microWindow);
        secondsAgos[3] = 0;

        // window lengths for each cumulative differencing
        // in terms of prices, will use for indexes
        //  0: priceOneMacroWindowAgo
        //  1: priceOverMacroWindow
        //  2: priceOverMicroWindow
        windows[0] = uint32(_macroWindow);
        windows[1] = uint32(_macroWindow);
        windows[2] = uint32(_microWindow);

        // index in secondsAgos which we treat as current time when differencing
        // for mean calcs
        nowIdxs[0] = 1;
        nowIdxs[1] = secondsAgos.length - 1;
        nowIdxs[2] = secondsAgos.length - 1;

        return (secondsAgos, windows, nowIdxs);
    }

    /// @dev returns input params needed for call to ovlWethPool consult
    function _inputsToConsultOvlWethPool(uint256 _microWindow, uint256 _macroWindow)
        private
        pure
        returns (
            uint32[] memory,
            uint32[] memory,
            uint256[] memory
        )
    {
        uint32[] memory secondsAgos = new uint32[](2);
        uint32[] memory windows = new uint32[](1);
        uint256[] memory nowIdxs = new uint256[](1);

        // number of seconds in past for which we want accumulator snapshot
        // for Oracle.Data, need:
        //  1. now (0 s ago)
        //  2. now - microWindow (microWindow seconds ago)
        secondsAgos[0] = uint32(_microWindow);
        secondsAgos[1] = 0;

        // window lengths for each cumulative differencing
        // in terms of prices, will use for indexes
        //  0: priceOvlWethOverMicroWindow
        windows[0] = uint32(_microWindow);

        // index in secondsAgos which we treat as current time when differencing
        // for mean calcs
        nowIdxs[0] = secondsAgos.length - 1;

        return (secondsAgos, windows, nowIdxs);
    }

    /// @dev COPIED AND MODIFIED FROM: Uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol
    /// @dev assumes nows elements are the current cumulative value from which we
    /// @dev want to calculate rolling average tick and liquidity values
    function consult(
        address pool,
        uint32[] memory secondsAgos,
        uint32[] memory windows,
        uint256[] memory nowIdxs
    )
        public
        view
        returns (int24[] memory arithmeticMeanTicks_, uint128[] memory harmonicMeanLiquidities_)
    {
        (
            int56[] memory tickCumulatives,
            uint160[] memory secondsPerLiquidityCumulativeX128s
        ) = IUniswapV3Pool(pool).observe(secondsAgos);

        arithmeticMeanTicks_ = new int24[](nowIdxs.length);
        harmonicMeanLiquidities_ = new uint128[](nowIdxs.length);

        for (uint256 i = 0; i < nowIdxs.length; i++) {
            uint32 secondsAgo = secondsAgos[i];
            uint256 nowIdx = nowIdxs[i];
            uint32 window = windows[i];

            int56 tickCumulativesDelta = tickCumulatives[nowIdx] - tickCumulatives[i];
            uint160 secondsPerLiquidityCumulativesDelta = secondsPerLiquidityCumulativeX128s[
                nowIdx
            ] - secondsPerLiquidityCumulativeX128s[i];

            int24 arithmeticMeanTick = int24(tickCumulativesDelta / int56(int32(window)));
            // Always round to negative infinity
            if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(int32(window)) != 0))
                arithmeticMeanTick--;

            // We are multiplying here instead of shifting to ensure that harmonicMeanLiquidity
            // doesn't overflow uint128
            uint192 windowX160 = uint192(window) * type(uint160).max;
            uint128 harmonicMeanLiquidity = uint128(
                windowX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32)
            );

            arithmeticMeanTicks_[i] = arithmeticMeanTick;
            harmonicMeanLiquidities_[i] = harmonicMeanLiquidity;
        }
    }

    /// @dev COPIED AND MODIFIED FROM: Uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) public view returns (uint256 quoteAmount_) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by
        // itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount_ = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount_ = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

    /// @dev virtual balance of WETH in the pool in OVL terms
    function getReserveInOvl(
        int24 arithmeticMeanTickMarket,
        uint128 harmonicMeanLiquidityMarket,
        int24 arithmeticMeanTickOvlWeth
    ) public view returns (uint256 reserveInOvl_) {
        uint256 reserveInWeth = getReserveInWeth(
            arithmeticMeanTickMarket,
            harmonicMeanLiquidityMarket
        );
        uint256 amountOfWethPerOvl = getQuoteAtTick(arithmeticMeanTickOvlWeth, ONE, ovl, WETH);
        reserveInOvl_ = FullMath.mulDiv(reserveInWeth, uint256(ONE), amountOfWethPerOvl);
    }

    /// @dev virtual balance of WETH in the pool
    function getReserveInWeth(int24 arithmeticMeanTickMarket, uint128 harmonicMeanLiquidityMarket)
        public
        view
        returns (uint256 reserveInWeth_)
    {
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(arithmeticMeanTickMarket);
        // WETH ? x (token0) : y(token1)
        reserveInWeth_ = marketToken0 == WETH
            ? FullMath.mulDiv(1 << 96, uint256(harmonicMeanLiquidityMarket), uint256(sqrtPriceX96))
            : FullMath.mulDiv(
                uint256(harmonicMeanLiquidityMarket),
                uint256(sqrtPriceX96),
                1 << 96
            );
    }
}
