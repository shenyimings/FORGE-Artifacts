// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../../../contracts/interfaces/CloberMarketSwapCallbackReceiver.sol";
import "../../../../../contracts/interfaces/CloberOrderBook.sol";
import "../../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../../contracts/GeometricPriceBook.sol";
import "../../../../../contracts/OrderNFT.sol";
import "../../../../../contracts/OrderBook.sol";
import "../../utils/MockingFactoryTest.sol";
import "../Constants.sol";

contract MarketOrderIntegrationTest is Test, CloberMarketSwapCallbackReceiver, MockingFactoryTest {
    event TakeOrder(address indexed payer, address indexed user, uint16 priceIndex, uint64 rawAmount, uint8 options);

    struct Order {
        uint64 rawAmount;
        uint16 priceIndex;
    }

    struct Vars {
        uint64 rawAmount;
        uint256 orderIndex;
        uint256 snapshotId;
        uint256 expectedAmountIn;
        uint256 expectedAmountOut;
        uint256 expectedTakerFee;
        uint256 beforePayerQuoteBalance;
        uint256 beforePayerBaseBalance;
        uint256 beforeTakerQuoteBalance;
        uint256 beforeTakerBaseBalance;
        uint256 beforePayerETHBalance;
    }

    struct Return {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 refundBounty;
    }

    uint16[20] prices;
    uint256 receivedEthers;
    MockQuoteToken quoteToken;
    MockBaseToken baseToken;
    OrderBook market;
    OrderNFT orderToken;

    function setUp() public {
        quoteToken = new MockQuoteToken();
        baseToken = new MockBaseToken();

        prices[0] = 1;
        prices[1] = 2;
        for (uint256 i = 2; i < 20; i++) {
            prices[i] = prices[i - 1] + prices[i - 2];
        }
    }

    receive() external payable {
        receivedEthers += msg.value;
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

    function _createMarket(int24 makerFee, uint24 takerFee) private {
        orderToken = new OrderNFT(address(this), address(this));
        market = new OrderBook(
            address(orderToken),
            address(quoteToken),
            address(baseToken),
            10**4,
            makerFee,
            takerFee,
            address(this),
            address(new GeometricPriceBook(Constants.GEOMETRIC_A, Constants.GEOMETRIC_R))
        );
        orderToken.init("", "", address(market));

        quoteToken.mint(address(this), type(uint128).max);
        quoteToken.approve(address(market), type(uint256).max);

        baseToken.mint(address(this), type(uint128).max);
        baseToken.approve(address(market), type(uint256).max);
    }

    function _createMarket(
        int24 makerFee,
        uint24 takerFee,
        uint128 r
    ) private {
        orderToken = new OrderNFT(address(this), address(this));
        market = new OrderBook(
            address(orderToken),
            address(quoteToken),
            address(baseToken),
            10**4,
            makerFee,
            takerFee,
            address(this),
            address(new GeometricPriceBook(Constants.GEOMETRIC_A, r))
        );
        orderToken.init("", "", address(market));

        quoteToken.mint(address(this), type(uint128).max);
        quoteToken.approve(address(market), type(uint256).max);

        baseToken.mint(address(this), type(uint128).max);
        baseToken.approve(address(market), type(uint256).max);
    }

    function _toArray(OrderKey memory orderKey) private pure returns (OrderKey[] memory) {
        OrderKey[] memory ids = new OrderKey[](1);
        ids[0] = orderKey;
        return ids;
    }

    function _calculateAmounts(
        bool isTakingBid,
        uint16 priceIndex,
        uint64 rawAmount
    ) private view returns (uint256 expectedAmountIn, uint256 expectedAmountOut) {
        expectedAmountIn = isTakingBid ? market.rawToBase(rawAmount, priceIndex, true) : market.rawToQuote(rawAmount);
        expectedAmountOut = isTakingBid ? market.rawToQuote(rawAmount) : market.rawToBase(rawAmount, priceIndex, false);
    }

    function _checkTakeOrder(
        bool isTakingBid,
        uint16 limitPriceIndex,
        uint64 rawAmount,
        uint256 baseAmount,
        Order memory expectedTakeOrder
    ) private {
        Vars memory vars;

        (vars.expectedAmountIn, vars.expectedAmountOut) = _calculateAmounts(
            isTakingBid,
            expectedTakeOrder.priceIndex,
            expectedTakeOrder.rawAmount
        );
        vars.expectedTakerFee = Math.divide(vars.expectedAmountOut * Constants.TAKE_FEE, Constants.FEE_PRECISION, true);
        vars.beforePayerQuoteBalance = quoteToken.balanceOf(address(this));
        vars.beforePayerBaseBalance = baseToken.balanceOf(address(this));
        vars.beforeTakerQuoteBalance = quoteToken.balanceOf(Constants.USER_B);
        vars.beforeTakerBaseBalance = baseToken.balanceOf(Constants.USER_B);

        {
            (uint256 inputAmount, uint256 outputAmount) = market.getExpectedAmount(
                limitPriceIndex,
                isTakingBid ? 0 : rawAmount,
                isTakingBid ? baseAmount : 0,
                isTakingBid ? 2 : 3
            );
            assertEq(inputAmount, vars.expectedAmountIn, "ERROR_BASE_BALANCE");
            assertEq(outputAmount, vars.expectedAmountOut - vars.expectedTakerFee, "ERROR_QUOTE_BALANCE");
        }

        vm.expectEmit(true, true, true, true);
        emit TakeOrder({
            payer: address(this),
            user: Constants.USER_B,
            rawAmount: expectedTakeOrder.rawAmount,
            priceIndex: expectedTakeOrder.priceIndex,
            options: isTakingBid ? 128 + 2 : 128 + 2 + 1
        });
        market.marketOrder(
            Constants.USER_B,
            limitPriceIndex,
            isTakingBid ? 0 : rawAmount,
            isTakingBid ? baseAmount : 0,
            isTakingBid ? 2 : 3,
            abi.encode(
                Return({
                    tokenIn: isTakingBid ? address(baseToken) : address(quoteToken),
                    tokenOut: isTakingBid ? address(quoteToken) : address(baseToken),
                    amountIn: vars.expectedAmountIn,
                    amountOut: vars.expectedAmountOut - vars.expectedTakerFee,
                    refundBounty: 0
                })
            )
        );
        if (isTakingBid) {
            assertEq(
                vars.beforePayerBaseBalance - baseToken.balanceOf(address(this)),
                vars.expectedAmountIn,
                "ERROR_BASE_BALANCE"
            );
            assertEq(
                quoteToken.balanceOf(Constants.USER_B) - vars.beforeTakerQuoteBalance,
                vars.expectedAmountOut - vars.expectedTakerFee,
                "ERROR_QUOTE_BALANCE"
            );
        } else {
            assertEq(
                vars.beforePayerQuoteBalance - quoteToken.balanceOf(address(this)),
                vars.expectedAmountIn,
                "ERROR_QUOTE_BALANCE"
            );
            assertEq(
                baseToken.balanceOf(Constants.USER_B) - vars.beforeTakerBaseBalance,
                vars.expectedAmountOut - vars.expectedTakerFee,
                "ERROR_BASE_BALANCE"
            );
        }
    }

    function _checkTakeOrders(
        bool isTakingBid,
        uint16 limitPriceIndex,
        uint64 rawAmount,
        uint256 baseAmount,
        Order[] memory expectedTakeOrders
    ) private {
        Vars memory vars;
        for (uint256 i = 0; i < expectedTakeOrders.length; i++) {
            (uint256 expectedAmountIn, uint256 expectedAmountOut) = _calculateAmounts(
                isTakingBid,
                expectedTakeOrders[i].priceIndex,
                expectedTakeOrders[i].rawAmount
            );
            vars.expectedAmountIn += expectedAmountIn;
            vars.expectedAmountOut += expectedAmountOut;
        }
        vars.expectedTakerFee = Math.divide(vars.expectedAmountOut * Constants.TAKE_FEE, Constants.FEE_PRECISION, true);
        vars.beforePayerQuoteBalance = quoteToken.balanceOf(address(this));
        vars.beforePayerBaseBalance = baseToken.balanceOf(address(this));
        vars.beforeTakerQuoteBalance = quoteToken.balanceOf(Constants.USER_B);
        vars.beforeTakerBaseBalance = baseToken.balanceOf(Constants.USER_B);

        for (uint256 i = 0; i < expectedTakeOrders.length; i++) {
            vars.snapshotId = vm.snapshot();
            {
                (uint256 inputAmount, uint256 outputAmount) = market.getExpectedAmount(
                    limitPriceIndex,
                    isTakingBid ? 0 : rawAmount,
                    isTakingBid ? baseAmount : 0,
                    isTakingBid ? 2 : 3
                );
                assertEq(inputAmount, vars.expectedAmountIn, "ERROR_BASE_BALANCE");
                assertEq(outputAmount, vars.expectedAmountOut - vars.expectedTakerFee, "ERROR_QUOTE_BALANCE");
            }
            vm.expectEmit(true, true, true, true);
            emit TakeOrder({
                payer: address(this),
                user: Constants.USER_B,
                rawAmount: expectedTakeOrders[i].rawAmount,
                priceIndex: expectedTakeOrders[i].priceIndex,
                options: isTakingBid ? 128 + 2 : 128 + 2 + 1
            });
            market.marketOrder(
                Constants.USER_B,
                limitPriceIndex,
                isTakingBid ? 0 : rawAmount,
                isTakingBid ? baseAmount : 0,
                isTakingBid ? 2 : 3,
                new bytes(0)
            );
            vm.revertTo(vars.snapshotId);
        }
        market.marketOrder(
            Constants.USER_B,
            limitPriceIndex,
            isTakingBid ? 0 : rawAmount,
            isTakingBid ? baseAmount : 0,
            isTakingBid ? 2 : 3,
            abi.encode(
                Return({
                    tokenIn: isTakingBid ? address(baseToken) : address(quoteToken),
                    tokenOut: isTakingBid ? address(quoteToken) : address(baseToken),
                    amountIn: vars.expectedAmountIn,
                    amountOut: vars.expectedAmountOut - vars.expectedTakerFee,
                    refundBounty: 0
                })
            )
        );
        if (isTakingBid) {
            assertEq(
                vars.beforePayerBaseBalance - baseToken.balanceOf(address(this)),
                vars.expectedAmountIn,
                "ERROR_BASE_BALANCE"
            );
            assertEq(
                quoteToken.balanceOf(Constants.USER_B) - vars.beforeTakerQuoteBalance,
                vars.expectedAmountOut - vars.expectedTakerFee,
                "ERROR_QUOTE_BALANCE"
            );
        } else {
            assertEq(
                vars.beforePayerQuoteBalance - quoteToken.balanceOf(address(this)),
                vars.expectedAmountIn,
                "ERROR_QUOTE_BALANCE"
            );
            assertEq(
                baseToken.balanceOf(Constants.USER_B) - vars.beforeTakerBaseBalance,
                vars.expectedAmountOut - vars.expectedTakerFee,
                "ERROR_BASE_BALANCE"
            );
        }
    }

    function _postOnlyWithFibonacciPrice(bool isBid) private {
        // Post Only In Fibonacci
        for (uint256 i = 0; i < 20; i++) {
            uint64 _rawAmount = 3 * prices[i];
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                prices[i],
                isBid ? _rawAmount : 0,
                isBid ? 0 : market.rawToBase(_rawAmount, prices[i], true),
                isBid ? 1 : 0,
                new bytes(0)
            );
        }
    }

    function testMarketAskWhenBidSideIsEmpty() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _checkTakeOrders(Constants.BID, 0, 0, 1000000, new Order[](0));
    }

    function testMarketBidWhenAskSideIsEmpty() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _checkTakeOrders(Constants.ASK, 0, 1000000, 0, new Order[](0));
    }

    function testBreakAtLimitPriceForMarketBid() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _postOnlyWithFibonacciPrice(Constants.BID);

        // Takes
        uint256 baseAmount = 0;
        for (uint256 i = 0; i < 20; i++) {
            baseAmount += market.rawToBase(3 * prices[19 - i], prices[19 - i], true);
        }
        Order[] memory expectedTakeOrders = new Order[](19);
        for (uint256 i = 0; i < 19; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[19 - i], priceIndex: prices[19 - i]});
        }
        _checkTakeOrders(Constants.BID, prices[1], 0, baseAmount, expectedTakeOrders);
        assertEq(market.getDepth(Constants.BID, prices[0]), 3 * prices[0], "ERROR_ORDER_AMOUNT");
        for (uint256 i = 1; i < 20; i++) {
            assertEq(market.getDepth(Constants.BID, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testBreakAtLimitPriceForMarketAsk() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _postOnlyWithFibonacciPrice(Constants.ASK);

        // Takes
        uint64 rawAmount = 0;
        for (uint256 i = 0; i < 20; i++) {
            rawAmount += 3 * prices[i];
        }
        Order[] memory expectedTakeOrders = new Order[](19);
        for (uint256 i = 0; i < 19; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[i], priceIndex: prices[i]});
        }
        _checkTakeOrders(Constants.ASK, prices[18], rawAmount, 0, expectedTakeOrders);
        assertEq(market.getDepth(Constants.ASK, prices[19]), 3 * prices[19], "ERROR_ORDER_AMOUNT");
        for (uint256 i = 0; i < 19; i++) {
            assertEq(market.getDepth(Constants.ASK, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testFillMultipleWithBid() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _postOnlyWithFibonacciPrice(Constants.BID);

        // Takes
        uint256 baseAmount = 0;
        for (uint256 i = 0; i < 20; i++) {
            baseAmount += market.rawToBase(3 * prices[19 - i], prices[19 - i], true);
        }
        Order[] memory expectedTakeOrders = new Order[](20);
        for (uint256 i = 0; i < 20; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[19 - i], priceIndex: prices[19 - i]});
        }
        _checkTakeOrders(Constants.BID, 0, 0, baseAmount, expectedTakeOrders);
        for (uint256 i = 0; i < 20; i++) {
            assertEq(market.getDepth(Constants.BID, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testFillMultipleWithAsk() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _postOnlyWithFibonacciPrice(Constants.ASK);

        // Takes
        uint64 rawAmount = 0;
        for (uint256 i = 0; i < 20; i++) {
            rawAmount += 3 * prices[i];
        }
        Order[] memory expectedTakeOrders = new Order[](20);
        for (uint256 i = 0; i < 20; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[i], priceIndex: prices[i]});
        }
        _checkTakeOrders(Constants.ASK, type(uint16).max, rawAmount, 0, expectedTakeOrders);
        for (uint256 i = 0; i < 20; i++) {
            assertEq(market.getDepth(Constants.ASK, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testPartialFillForHighestBidOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _postOnlyWithFibonacciPrice(Constants.BID);

        // Takes
        uint256 baseAmount = 0;
        for (uint256 i = 0; i < 19; i++) {
            baseAmount += market.rawToBase(3 * prices[19 - i], prices[19 - i], true);
        }
        Order[] memory expectedTakeOrders = new Order[](19);
        for (uint256 i = 0; i < 19; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[19 - i], priceIndex: prices[19 - i]});
        }
        _checkTakeOrders(Constants.BID, prices[1], 0, baseAmount, expectedTakeOrders);
        assertEq(market.getDepth(Constants.BID, prices[0]), 3 * prices[0], "ERROR_ORDER_AMOUNT");
        for (uint256 i = 1; i < 20; i++) {
            assertEq(market.getDepth(Constants.BID, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testPartialFillForLowestAskOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _postOnlyWithFibonacciPrice(Constants.ASK);

        // Takes
        uint64 rawAmount = 0;
        for (uint256 i = 0; i < 19; i++) {
            rawAmount += 3 * prices[i];
        }
        Order[] memory expectedTakeOrders = new Order[](19);
        for (uint256 i = 0; i < 19; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[i], priceIndex: prices[i]});
        }
        _checkTakeOrders(Constants.ASK, prices[18], rawAmount, 0, expectedTakeOrders);
        assertEq(market.getDepth(Constants.ASK, prices[19]), 3 * prices[19], "ERROR_ORDER_AMOUNT");
        for (uint256 i = 0; i < 19; i++) {
            assertEq(market.getDepth(Constants.ASK, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testBidWithRefund() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _postOnlyWithFibonacciPrice(Constants.BID);

        // Takes
        uint256 baseAmount = 0;
        for (uint256 i = 0; i < 20; i++) {
            baseAmount += market.rawToBase(3 * prices[19 - i], prices[19 - i], true);
        }
        baseAmount += market.rawToBase(1225, 1, true); // refund
        Order[] memory expectedTakeOrders = new Order[](20);
        for (uint256 i = 0; i < 20; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[19 - i], priceIndex: prices[19 - i]});
        }
        _checkTakeOrders(Constants.BID, 0, 0, baseAmount, expectedTakeOrders);
        for (uint256 i = 0; i < 20; i++) {
            assertEq(market.getDepth(Constants.BID, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testAskWithRefund() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        _postOnlyWithFibonacciPrice(Constants.ASK);

        // Takes
        uint64 rawAmount = 0;
        for (uint256 i = 0; i < 20; i++) {
            rawAmount += 3 * prices[i];
        }
        rawAmount += 1225;
        Order[] memory expectedTakeOrders = new Order[](20);
        for (uint256 i = 0; i < 20; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[i], priceIndex: prices[i]});
        }
        _checkTakeOrders(Constants.ASK, type(uint16).max, rawAmount, 0, expectedTakeOrders);
        for (uint256 i = 0; i < 20; i++) {
            assertEq(market.getDepth(Constants.ASK, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testMarketBidWithCanceledOrders() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(Constants.USER_A, 5, 2, 0, 1, new bytes(0));
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(Constants.USER_A, 3, 2, 0, 1, new bytes(0));
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(Constants.USER_A, 1, 2, 0, 1, new bytes(0));

        assertEq(market.bestPriceIndex(Constants.BID), 5);
        vm.prank(Constants.USER_A);
        market.cancel(Constants.USER_A, _toArray(OrderKey({isBid: Constants.BID, priceIndex: 3, orderIndex: 0})));
        assertEq(market.bestPriceIndex(Constants.BID), 5);

        // Takes
        uint256 baseAmount = market.rawToBase(2, 5, true) + market.rawToBase(2, 1, true);
        Order[] memory expectedTakeOrders = new Order[](2);
        expectedTakeOrders[0] = Order({rawAmount: 2, priceIndex: 5});
        expectedTakeOrders[1] = Order({rawAmount: 2, priceIndex: 1});
        _checkTakeOrders(Constants.BID, 0, 0, baseAmount, expectedTakeOrders);
        assertTrue(market.isEmpty(Constants.BID));
    }

    function testMarketAskWithCanceledOrders() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            1,
            0,
            market.rawToBase(2, 1, true),
            0,
            new bytes(0)
        );
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            3,
            0,
            market.rawToBase(2, 3, true),
            0,
            new bytes(0)
        );
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            5,
            0,
            market.rawToBase(2, 5, true),
            0,
            new bytes(0)
        );

        assertEq(market.bestPriceIndex(Constants.ASK), 1);
        vm.prank(Constants.USER_A);
        market.cancel(Constants.USER_A, _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 3, orderIndex: 0})));
        assertEq(market.bestPriceIndex(Constants.ASK), 1);

        // Takes
        uint64 rawAmount = 2 + 2;
        Order[] memory expectedTakeOrders = new Order[](2);
        expectedTakeOrders[0] = Order({rawAmount: 2, priceIndex: 5});
        expectedTakeOrders[1] = Order({rawAmount: 2, priceIndex: 1});
        _checkTakeOrders(Constants.ASK, type(uint16).max, rawAmount, 0, expectedTakeOrders);
        assertTrue(market.isEmpty(Constants.ASK));
    }

    function testLargeBidOrderFlow() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < vm.envOr("LARGE_ORDER_COUNT", Constants.LARGE_ORDER_COUNT); i++) {
            // Make
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                777,
                0,
                1,
                new bytes(0)
            );

            // Take
            _checkTakeOrder(
                Constants.BID,
                0,
                0,
                market.rawToBase(777, 3, true),
                Order({rawAmount: 777, priceIndex: 3})
            );
        }
    }

    function testLargeAskOrderFlow() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < vm.envOr("LARGE_ORDER_COUNT", Constants.LARGE_ORDER_COUNT); i++) {
            // Make
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                0,
                market.rawToBase(777, priceIndex, true),
                0,
                new bytes(0)
            );

            // Take
            _checkTakeOrder(Constants.ASK, type(uint16).max, 777, 0, Order({rawAmount: 777, priceIndex: 3}));
        }
    }

    function testFullyHorizontalFillingBid() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < Constants.MAX_ORDER; i++) {
            // Make
            uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                777,
                0,
                1,
                new bytes(0)
            );
            assertEq(orderIndex, i, "ERROR_ORDER_INDEX");
        }
        // Take all
        _checkTakeOrder(
            Constants.BID,
            0,
            0,
            market.rawToBase(777, 3, true) * uint64(Constants.MAX_ORDER),
            Order({rawAmount: 777 * uint64(Constants.MAX_ORDER), priceIndex: 3})
        );
    }

    function testFullyHorizontalFillingAsk() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < Constants.MAX_ORDER; i++) {
            // Make
            uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                0,
                market.rawToBase(777, priceIndex, true),
                0,
                new bytes(0)
            );
            assertEq(orderIndex, i, "ERROR_ORDER_INDEX");
        }
        // Take all
        _checkTakeOrder(
            Constants.ASK,
            type(uint16).max,
            777 * uint64(Constants.MAX_ORDER),
            0,
            Order({rawAmount: 777 * uint64(Constants.MAX_ORDER), priceIndex: 3})
        );
    }

    function testVerticalBidOrderFlowR1001() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;
        uint256 baseAmount = 0;
        // To prevent too large price : 313 * 128 = 40064
        Order[] memory expectedTakeOrders = new Order[](313);
        for (uint16 i = 0; i < 313; i++) {
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                rawAmount,
                0,
                1,
                new bytes(0)
            );
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            baseAmount += market.rawToBase(rawAmount, priceIndex, true);
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.BID, 0, 0, baseAmount, expectedTakeOrders);
    }

    function testVerticalAskOrderFlowR1001() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;
        // To prevent too large price : 313 * 128 = 40064
        Order[] memory expectedTakeOrders = new Order[](313);
        for (uint16 i = 0; i < 313; i++) {
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                0,
                market.rawToBase(rawAmount, priceIndex, true),
                0,
                new bytes(0)
            );
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.ASK, type(uint16).max, rawAmount * 313, 0, expectedTakeOrders);
    }

    function testVerticalClaimedBidOrderFlowR1001() public {
        testVerticalBidOrderFlowR1001();

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;
        uint256 baseAmount = 0;
        // To prevent too large price : 313 * 128 = 40064
        Order[] memory expectedTakeOrders = new Order[](313);
        for (uint16 i = 0; i < 313; i++) {
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                rawAmount,
                0,
                1,
                new bytes(0)
            );
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            baseAmount += market.rawToBase(rawAmount, priceIndex, true);
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.BID, 0, 0, baseAmount, expectedTakeOrders);
    }

    function testVerticalClaimedAskOrderFlowR1001() public {
        testVerticalAskOrderFlowR1001();

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;
        // To prevent too large price : 313 * 128 = 40064
        Order[] memory expectedTakeOrders = new Order[](313);
        for (uint16 i = 0; i < 313; i++) {
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                0,
                market.rawToBase(rawAmount, priceIndex, true),
                0,
                new bytes(0)
            );
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.ASK, type(uint16).max, rawAmount * 313, 0, expectedTakeOrders);
    }

    function testVerticalBidOrderFlowR101() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE, 101 * 10**16);

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;
        uint256 baseAmount = 0;
        // To prevent too large price : 34 * 128 = 4352
        Order[] memory expectedTakeOrders = new Order[](34);
        for (uint16 i = 0; i < 34; i++) {
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                rawAmount,
                0,
                1,
                new bytes(0)
            );
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            baseAmount += market.rawToBase(rawAmount, priceIndex, true);
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.BID, 0, 0, baseAmount, expectedTakeOrders);
    }

    function testVerticalAskOrderFlowR101() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;
        // To prevent too large price : 34 * 128 = 4352
        Order[] memory expectedTakeOrders = new Order[](34);
        for (uint16 i = 0; i < 34; i++) {
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                0,
                market.rawToBase(rawAmount, priceIndex, true),
                0,
                new bytes(0)
            );
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.ASK, type(uint16).max, rawAmount * 313, 0, expectedTakeOrders);
    }

    function testVerticalClaimedBidOrderFlowR101() public {
        testVerticalBidOrderFlowR101();

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;
        uint256 baseAmount = 0;
        // To prevent too large price : 34 * 128 = 4352
        Order[] memory expectedTakeOrders = new Order[](34);
        for (uint16 i = 0; i < 34; i++) {
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                rawAmount,
                0,
                1,
                new bytes(0)
            );
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            baseAmount += market.rawToBase(rawAmount, priceIndex, true);
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.BID, 0, 0, baseAmount, expectedTakeOrders);
    }

    function testVerticalClaimedAskOrderFlowR101() public {
        testVerticalAskOrderFlowR101();

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;
        // To prevent too large price : 34 * 128 = 4352
        Order[] memory expectedTakeOrders = new Order[](34);
        for (uint16 i = 0; i < 34; i++) {
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                0,
                market.rawToBase(rawAmount, priceIndex, true),
                0,
                new bytes(0)
            );
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.ASK, type(uint16).max, rawAmount * 313, 0, expectedTakeOrders);
    }

    function testMarketBidWithInvalidPriceIndexWithR101() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE, 101 * 10**16);

        uint64 rawAmount = 3;
        uint16 maxPriceIndex = CloberPriceBook(market.priceBook()).maxPriceIndex();
        market.limitOrder(
            Constants.USER_A,
            maxPriceIndex,
            0,
            market.rawToBase(rawAmount, maxPriceIndex, true),
            0,
            new bytes(0)
        );

        Order[] memory expectedTakeOrders = new Order[](1);
        expectedTakeOrders[0] = Order({rawAmount: rawAmount, priceIndex: maxPriceIndex});
        _checkTakeOrders(Constants.ASK, type(uint16).max, rawAmount, 0, expectedTakeOrders);
    }

    function testMarketAskWithInvalidPriceIndexWithR101() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE, 101 * 10**16);

        uint64 rawAmount = 3;
        uint16 maxPriceIndex = CloberPriceBook(market.priceBook()).maxPriceIndex();
        market.limitOrder(Constants.USER_A, maxPriceIndex, rawAmount, 0, 1, new bytes(0));

        Order[] memory expectedTakeOrders = new Order[](1);
        expectedTakeOrders[0] = Order({rawAmount: rawAmount, priceIndex: maxPriceIndex});
        _checkTakeOrders(Constants.BID, 0, 0, market.rawToBase(rawAmount, maxPriceIndex, true), expectedTakeOrders);
    }
}
