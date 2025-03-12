// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../../contracts/interfaces/CloberMarketSwapCallbackReceiver.sol";
import "../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../contracts/mocks/MockPriceBook.sol";
import "../../../../contracts/OrderNFT.sol";
import "../../../../contracts/OrderBook.sol";
import "./Constants.sol";

contract OrderBookMarketOrderUnitTest is Test, CloberMarketSwapCallbackReceiver {
    event TakeOrder(address indexed payer, address indexed user, uint16 priceIndex, uint64 rawAmount, uint8 options);

    struct Return {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 refundBounty;
    }

    MockQuoteToken quoteToken;
    MockBaseToken baseToken;
    OrderBook orderBook;
    OrderNFT orderToken;

    function setUp() public {
        quoteToken = new MockQuoteToken();
        baseToken = new MockBaseToken();
    }

    function cloberMarketSwapCallback(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata data
    ) external payable {
        if (data.length != 0) {
            Return memory expectedReturn = abi.decode(data, (Return));
            assertEq(tokenIn, expectedReturn.tokenIn, "ERROR_TOKEN_IN");
            assertEq(tokenOut, expectedReturn.tokenOut, "ERROR_TOKEN_OUT");
            assertEq(amountIn, expectedReturn.amountIn, "ERROR_AMOUNT_IN");
            assertEq(amountOut, expectedReturn.amountOut, "ERROR_AMOUNT_OUT");
            assertEq(msg.value, expectedReturn.refundBounty, "ERROR_REFUND_BOUNTY");
        }
        IERC20(tokenIn).transfer(msg.sender, amountIn);
    }

    function _createOrderBook(int24 makerFee, uint24 takerFee) private {
        orderToken = new OrderNFT(address(this), address(this));
        orderBook = new OrderBook(
            address(orderToken),
            address(quoteToken),
            address(baseToken),
            1,
            makerFee,
            takerFee,
            address(this),
            address(new MockPriceBook())
        );
        orderToken.init("", "", address(orderBook));

        uint256 _quotePrecision = 10**quoteToken.decimals();
        quoteToken.mint(address(this), 1000000000 * _quotePrecision);
        quoteToken.approve(address(orderBook), type(uint256).max);

        uint256 _basePrecision = 10**baseToken.decimals();
        baseToken.mint(address(this), 1000000000 * _basePrecision);
        baseToken.approve(address(orderBook), type(uint256).max);
    }

    function _buildMarketOrderOptions(bool isBid, bool expendInput) internal pure returns (uint8) {
        return (isBid ? 1 : 0) + (expendInput ? 2 : 0);
    }

    function _createPostOnlyOrder(bool isBid) private {
        return _createPostOnlyOrder(isBid, Constants.PRICE_INDEX);
    }

    function _createPostOnlyOrder(bool isBid, uint16 priceIndex) private {
        if (isBid) {
            orderBook.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}({
                user: Constants.MAKER,
                priceIndex: priceIndex,
                rawAmount: Constants.RAW_AMOUNT,
                baseAmount: 0,
                options: 3,
                data: new bytes(0)
            });
        } else {
            orderBook.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}({
                user: Constants.MAKER,
                priceIndex: priceIndex,
                rawAmount: 0,
                baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, priceIndex, true),
                options: 2,
                data: new bytes(0)
            });
        }
    }

    function testBusinessLogic() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.ASK);

        uint256 amountIn = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        uint256 amountOut = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false);

        uint256 beforePayerQuoteBalance = quoteToken.balanceOf(address(this));
        uint256 beforeTakerBaseBalance = baseToken.balanceOf(Constants.TAKER);
        {
            (uint256 inputAmount, uint256 outputAmount) = orderBook.getExpectedAmount(
                Constants.LIMIT_BID_PRICE,
                Constants.RAW_AMOUNT,
                0,
                _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT)
            );
            assertEq(inputAmount, amountIn, "ERROR_BASE_BALANCE");
            assertEq(outputAmount, amountOut, "ERROR_QUOTE_BALANCE");
        }
        vm.expectEmit(true, true, true, true);
        emit TakeOrder({
            payer: address(this),
            user: Constants.TAKER,
            rawAmount: Constants.RAW_AMOUNT,
            priceIndex: Constants.PRICE_INDEX,
            options: 128 + 2 + 1 // marketOrder & ExpendInput & BID
        });
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: abi.encode(
                Return({
                    tokenIn: address(quoteToken),
                    tokenOut: address(baseToken),
                    amountIn: amountIn,
                    amountOut: amountOut,
                    refundBounty: 0
                })
            )
        });
        assertEq(baseToken.balanceOf(Constants.TAKER) - beforeTakerBaseBalance, amountOut, "ERROR_BASE_BALANCE");
        assertEq(orderBook.getDepth(Constants.ASK, Constants.PRICE_INDEX), 0, "ERROR_ORDER_AMOUNT");
        assertEq(beforePayerQuoteBalance - quoteToken.balanceOf(address(this)), amountIn, "ERROR_QUOTE_BALANCE");
    }

    function testMarketOrderExpendOutputWithMaxSlippage() public {
        _createOrderBook(0, Constants.TAKE_FEE);

        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX + 1);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX + 2);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX + 3);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX + 4);

        (uint256 inputAmount, uint256 outputAmount) = orderBook.getExpectedAmount(
            Constants.LIMIT_ASK_PRICE,
            Constants.RAW_AMOUNT * 4,
            type(uint256).max,
            _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_OUTPUT)
        );

        uint256 beforePayerQuoteBalance = quoteToken.balanceOf(Constants.TAKER);
        uint256 beforeTakerBaseBalance = baseToken.balanceOf(address(this));
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: Constants.RAW_AMOUNT * 4,
            baseAmount: type(uint256).max, // max slippage
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_OUTPUT),
            data: new bytes(0)
        });
        assertEq(beforeTakerBaseBalance - baseToken.balanceOf(address(this)), inputAmount, "ERROR_BASE_BALANCE");
        assertEq(quoteToken.balanceOf(Constants.TAKER) - beforePayerQuoteBalance, outputAmount, "ERROR_QUOTE_BALANCE");
    }

    function testFuzzMarketOrderExpendOutputWithMaxSlippage(uint24 takerFee, uint64 rawAmount) public {
        takerFee = uint24(bound(takerFee, 0, Constants.MAX_FEE));
        rawAmount = uint64(bound(rawAmount, Constants.RAW_AMOUNT, Constants.RAW_AMOUNT * 4));
        _createOrderBook(0, Constants.TAKE_FEE);

        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX + 1);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX + 2);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX + 3);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX + 4);

        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: rawAmount,
            baseAmount: type(uint256).max, // max slippage
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_OUTPUT),
            data: new bytes(0)
        });
    }

    function testBreakAtLimitPriceInTaking() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID);

        uint256 beforeTakerBaseBalance = baseToken.balanceOf(Constants.TAKER);
        {
            (uint256 inputAmount, uint256 outputAmount) = orderBook.getExpectedAmount(
                Constants.PRICE_INDEX + 1,
                0,
                100,
                _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT)
            );
            assertEq(inputAmount, 0, "ERROR_BASE_BALANCE");
            assertEq(outputAmount, 0, "ERROR_QUOTE_BALANCE");
        }
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.PRICE_INDEX + 1,
            rawAmount: 0,
            baseAmount: 100,
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: abi.encode(
                Return({
                    tokenIn: address(baseToken),
                    tokenOut: address(quoteToken),
                    amountIn: 0,
                    amountOut: 0,
                    refundBounty: 0
                })
            )
        });
        assertEq(baseToken.balanceOf(Constants.TAKER) - beforeTakerBaseBalance, 0, "ERROR_BASE_BALANCE");
        assertEq(orderBook.getDepth(Constants.ASK, Constants.PRICE_INDEX), 0, "ERROR_ORDER_AMOUNT");
    }

    function testEmptyMarketOrder() public {
        _createOrderBook(0, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        orderBook.marketOrder(
            address(this),
            0,
            0,
            0,
            _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            new bytes(0)
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        orderBook.marketOrder(
            address(this),
            type(uint16).max,
            0,
            0,
            _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            new bytes(0)
        );
    }

    function testOverflowInBaseToRawOnTake() public {
        _createOrderBook(0, 0);

        uint256 _quotePrecision = 10**quoteToken.decimals();
        quoteToken.mint(address(this), type(uint128).max * _quotePrecision);
        quoteToken.approve(address(this), type(uint256).max);
        orderBook.limitOrder(address(this), Constants.PRICE_INDEX, type(uint64).max - 1, 0, 1, new bytes(0));

        uint256 _basePrecision = 10**baseToken.decimals();
        baseToken.mint(address(this), type(uint128).max * _basePrecision);
        uint256 balance = baseToken.balanceOf(address(this));
        uint8 options = _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.OVERFLOW_UNDERFLOW));
        orderBook.marketOrder(address(this), Constants.PRICE_INDEX, 0, balance, options, new bytes(0));
    }

    function testOverflowInQuoteToRawOnTake() public {
        orderToken = new OrderNFT(address(this), address(this));
        orderBook = new OrderBook(
            address(orderToken),
            address(quoteToken),
            address(baseToken),
            1,
            0,
            Constants.MAX_FEE,
            address(this),
            address(new MockPriceBook())
        );
        orderToken.init("", "", address(orderBook));

        uint256 _quotePrecision = 10**quoteToken.decimals();
        quoteToken.mint(address(this), type(uint128).max * _quotePrecision);
        quoteToken.approve(address(this), type(uint256).max);
        orderBook.limitOrder(address(this), Constants.PRICE_INDEX, type(uint64).max - 1, 0, 1, new bytes(0));

        uint8 options = _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_OUTPUT);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.OVERFLOW_UNDERFLOW));
        orderBook.marketOrder(address(this), Constants.PRICE_INDEX, type(uint64).max - 1, 0, options, new bytes(0));
    }

    function testSlippageWithBidWithExpendInput() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.ASK);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.SLIPPAGE));
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: type(uint256).max,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
    }

    function testSlippageWithAskWithExpendInput() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID);

        uint256 amountIn = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.SLIPPAGE));
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: type(uint64).max,
            baseAmount: amountIn,
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
    }

    function testSlippageWithBidWithExpendOutput() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.ASK);

        uint256 amountOut = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.SLIPPAGE));
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: 0,
            baseAmount: amountOut,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_OUTPUT),
            data: new bytes(0)
        });
    }

    function testSlippageWithAskWithExpendOutput() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.SLIPPAGE));
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_OUTPUT),
            data: new bytes(0)
        });
    }

    function testReturnZeroWhenHeapIsEmpty() public {
        _createOrderBook(0, Constants.TAKE_FEE);

        (uint256 inputAmount, uint256 outputAmount) = orderBook.getExpectedAmount(
            Constants.LIMIT_BID_PRICE,
            Constants.RAW_AMOUNT,
            0,
            _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT)
        );
        assertEq(inputAmount, 0, "ERROR_AMOUNT_IN");
        assertEq(outputAmount, 0, "ERROR_AMOUNT_OUT");
    }

    function testReturnZeroWhenZeroAmount() public {
        _createOrderBook(0, Constants.TAKE_FEE);

        _createPostOnlyOrder(Constants.ASK);

        (uint256 inputAmount, uint256 outputAmount) = orderBook.getExpectedAmount(
            Constants.LIMIT_BID_PRICE,
            0,
            0,
            _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT)
        );
        assertEq(inputAmount, 0, "ERROR_AMOUNT_IN");
        assertEq(outputAmount, 0, "ERROR_AMOUNT_OUT");
    }

    function testWhileLoop() public {
        _createOrderBook(0, 0);

        for (uint256 i = 0; i < 36860; i++) {
            _createPostOnlyOrder(Constants.BID, uint16(i));
        }

        // this iterates over all price indices, instead of returning early as soon as `takenRawAmount == 0`
        (uint256 inputAmount, uint256 outputAmount) = orderBook.getExpectedAmount{gas: 100_000}(
            1,
            0,
            1,
            _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT)
        );
        assertEq(inputAmount, 0, "ERROR_AMOUNT_IN");
        assertEq(outputAmount, 0, "ERROR_AMOUNT_OUT");
    }

    function testTradeLogWithBidsInSameBlocks() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.ASK);

        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });

        CloberOrderBook.BlockTradeLog memory tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, 0, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT, "ERROR_BID_VOLUME");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX, "ERROR_CLOSE");
        assertEq(tradeLog.high, Constants.PRICE_INDEX, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");

        // take will be in same block
        _createPostOnlyOrder(Constants.ASK);

        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, 0, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT + Constants.RAW_AMOUNT, "ERROR_BID_VOLUME");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX, "ERROR_CLOSE");
        assertEq(tradeLog.high, Constants.PRICE_INDEX, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
    }

    function testTradeLogWithBidsInDistinctBlocks() public {
        testTradeLogWithBidsInSameBlocks();
        assertEq(orderBook.blockTradeLogIndex(), 0, "ERROR_BLOCK_TRADE_LOG_INDEX");

        vm.warp(block.timestamp + 1);
        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX * 3);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        assertEq(orderBook.blockTradeLogIndex(), 1, "ERROR_BLOCK_TRADE_LOG_INDEX");
        CloberOrderBook.BlockTradeLog memory tradeLog = orderBook.blockTradeLogs(1);
        assertEq(tradeLog.blockTime, block.timestamp, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, 0, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT, "ERROR_BID_VOLUME");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 3, "ERROR_CLOSE");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");

        vm.warp(block.timestamp + 1);
        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX * 2);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        assertEq(orderBook.blockTradeLogIndex(), 2, "ERROR_BLOCK_TRADE_LOG_INDEX");
        tradeLog = orderBook.blockTradeLogs(2);
        assertEq(tradeLog.blockTime, block.timestamp, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, 0, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT, "ERROR_BID_VOLUME");
        assertEq(tradeLog.open, Constants.PRICE_INDEX * 3, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 2, "ERROR_CLOSE");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX * 2, "ERROR_LOW");
    }

    function testTradeLogWithAsksInSameBlocks() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID);

        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });

        CloberOrderBook.BlockTradeLog memory tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.bidVolume, 0, "ERROR_BID_VOLUME");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX, "ERROR_CLOSE");
        assertEq(tradeLog.high, Constants.PRICE_INDEX, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");

        // take will be in same block
        _createPostOnlyOrder(Constants.BID);

        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT + Constants.RAW_AMOUNT, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.bidVolume, 0, "ERROR_BID_VOLUME");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX, "ERROR_CLOSE");
        assertEq(tradeLog.high, Constants.PRICE_INDEX, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
    }

    function testTradeLogWithAsksInDistinctBlocks() public {
        testTradeLogWithAsksInSameBlocks();
        assertEq(orderBook.blockTradeLogIndex(), 0, "ERROR_BLOCK_TRADE_LOG_INDEX");

        vm.warp(block.timestamp + 1);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX * 3);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX * 3, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        assertEq(orderBook.blockTradeLogIndex(), 1, "ERROR_BLOCK_TRADE_LOG_INDEX");
        CloberOrderBook.BlockTradeLog memory tradeLog = orderBook.blockTradeLogs(1);
        assertEq(tradeLog.blockTime, block.timestamp, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.bidVolume, 0, "ERROR_BID_VOLUME");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 3, "ERROR_CLOSE");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");

        vm.warp(block.timestamp + 1);
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX * 2);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX * 2, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        assertEq(orderBook.blockTradeLogIndex(), 2, "ERROR_BLOCK_TRADE_LOG_INDEX");
        tradeLog = orderBook.blockTradeLogs(2);
        assertEq(tradeLog.blockTime, block.timestamp, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.bidVolume, 0, "ERROR_BID_VOLUME");
        assertEq(tradeLog.open, Constants.PRICE_INDEX * 3, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 2, "ERROR_CLOSE");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX * 2, "ERROR_LOW");
    }

    function testTradeLogWithBidForPriceIncrease() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        CloberOrderBook.BlockTradeLog memory tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT, "ERROR_BID_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX, "ERROR_CLOSE");

        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX * 2);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT * 2, "ERROR_BID_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 2, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 2, "ERROR_CLOSE");

        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX * 3);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT * 3, "ERROR_BID_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 3, "ERROR_CLOSE");
    }

    function testTradeLogWithAskForPriceIncrease() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        CloberOrderBook.BlockTradeLog memory tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX, "ERROR_CLOSE");

        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX * 2);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX * 2, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT * 2, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 2, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 2, "ERROR_CLOSE");

        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX * 3);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX * 3, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT * 3, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 3, "ERROR_CLOSE");
    }

    function testTradeLogWithBidForPriceDecrease() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX * 3);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        CloberOrderBook.BlockTradeLog memory tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT, "ERROR_BID_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX * 3, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX * 3, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 3, "ERROR_CLOSE");

        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX * 2);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT * 2, "ERROR_BID_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX * 2, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX * 3, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 2, "ERROR_CLOSE");

        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_BID_PRICE,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.bidVolume, Constants.RAW_AMOUNT * 3, "ERROR_BID_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX * 3, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 1, "ERROR_CLOSE");
    }

    function testTradeLogWithAskForPriceDecrease() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX * 3);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX * 3, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        CloberOrderBook.BlockTradeLog memory tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX * 3, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX * 3, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 3, "ERROR_CLOSE");

        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX * 2);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX * 2, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT * 2, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX * 2, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX * 3, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX * 2, "ERROR_CLOSE");

        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX);
        orderBook.marketOrder({
            user: Constants.TAKER,
            limitPriceIndex: Constants.LIMIT_ASK_PRICE,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true),
            options: _buildMarketOrderOptions(Constants.ASK, Constants.EXPEND_INPUT),
            data: new bytes(0)
        });
        tradeLog = orderBook.blockTradeLogs(0);
        assertEq(tradeLog.blockTime, 1, "ERROR_BLOCK_TIME");
        assertEq(tradeLog.askVolume, Constants.RAW_AMOUNT * 3, "ERROR_ASK_VOLUME");
        assertEq(tradeLog.high, Constants.PRICE_INDEX * 3, "ERROR_HIGH");
        assertEq(tradeLog.low, Constants.PRICE_INDEX, "ERROR_LOW");
        assertEq(tradeLog.open, Constants.PRICE_INDEX * 3, "ERROR_OPEN");
        assertEq(tradeLog.close, Constants.PRICE_INDEX, "ERROR_CLOSE");
    }

    function testTradeLogLargeTradeSize() public {
        _createOrderBook(0, 0);

        CloberOrderBook.BlockTradeLog memory tradeLog;
        for (uint32 i = 0; i <= 66000; i++) {
            _createPostOnlyOrder(Constants.ASK);

            orderBook.marketOrder({
                user: Constants.TAKER,
                limitPriceIndex: Constants.LIMIT_BID_PRICE,
                rawAmount: Constants.RAW_AMOUNT,
                baseAmount: 0,
                options: _buildMarketOrderOptions(Constants.BID, Constants.EXPEND_INPUT),
                data: new bytes(0)
            });

            uint16 expectedIndex = uint16(i % 65536);
            tradeLog = orderBook.blockTradeLogs(expectedIndex);
            assertEq(orderBook.blockTradeLogIndex(), expectedIndex, "ERROR_BLOCK_TRADE_LOG_INDEX");
            assertEq(tradeLog.blockTime, uint64(i) + 1, "ERROR_BLOCK_TIME");
            vm.warp(block.timestamp + 1);
        }
    }
}
