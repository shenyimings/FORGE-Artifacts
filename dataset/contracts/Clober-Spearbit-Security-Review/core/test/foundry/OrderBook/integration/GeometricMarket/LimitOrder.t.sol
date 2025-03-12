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

contract LimitOrderIntegrationTest is Test, CloberMarketSwapCallbackReceiver, MockingFactoryTest {
    using OrderKeyUtils for OrderKey;
    event MakeOrder(
        address indexed sender,
        address indexed user,
        uint64 rawAmount,
        uint32 claimBounty,
        uint256 orderIndex,
        uint16 priceIndex,
        uint8 options
    );
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

    function _checkMakeOrder(
        bool isBid,
        uint64 rawAmount,
        uint16 priceIndex
    ) private returns (uint256) {
        return _checkMakeOrder(isBid, rawAmount, priceIndex, 0);
    }

    function _checkMakeOrder(
        bool isBid,
        uint64 rawAmount,
        uint16 priceIndex,
        uint256 expectedOrderIndex
    ) private returns (uint256) {
        Vars memory vars;
        vars.expectedAmountIn = isBid ? market.rawToQuote(rawAmount) : market.rawToBase(rawAmount, priceIndex, true);
        vm.expectCall(
            address(orderToken),
            abi.encodeCall(
                CloberOrderNFT.onMint,
                (Constants.USER_A, OrderKey(isBid, priceIndex, expectedOrderIndex).encode())
            )
        );
        vm.expectEmit(true, true, true, true);
        emit MakeOrder({
            sender: address(this),
            user: Constants.USER_A,
            rawAmount: rawAmount,
            claimBounty: uint32(Constants.CLAIM_BOUNTY),
            orderIndex: expectedOrderIndex,
            priceIndex: priceIndex,
            options: isBid ? 1 : 0
        });
        vars.beforePayerBaseBalance = baseToken.balanceOf(address(this));
        vars.beforePayerQuoteBalance = quoteToken.balanceOf(address(this));
        vars.beforePayerETHBalance = address(address(this)).balance;
        vars.orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            isBid ? rawAmount : 0,
            isBid ? 0 : market.rawToBase(rawAmount, priceIndex, true),
            isBid ? 1 : 0,
            abi.encode(
                Return({
                    tokenIn: isBid ? address(quoteToken) : address(baseToken),
                    tokenOut: isBid ? address(baseToken) : address(quoteToken),
                    amountIn: vars.expectedAmountIn,
                    amountOut: 0,
                    refundBounty: 0
                })
            )
        );
        assertGt(market.getDepth(isBid, priceIndex), 0, "ERROR_ORDER_AMOUNT");
        assertEq(
            vars.beforePayerETHBalance - address(this).balance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY"
        );
        assertEq(
            orderToken.ownerOf(orderToken.encodeId(OrderKey(isBid, priceIndex, expectedOrderIndex))),
            Constants.USER_A,
            "ERROR_NFT_OWNER"
        );
        if (isBid) {
            assertEq(
                vars.beforePayerQuoteBalance - quoteToken.balanceOf(address(this)),
                vars.expectedAmountIn,
                "ERROR_QUOTE_BALANCE"
            );
        } else {
            assertEq(
                vars.beforePayerBaseBalance - baseToken.balanceOf(address(this)),
                vars.expectedAmountIn,
                "ERROR_BASE_BALANCE"
            );
        }
        return vars.orderIndex;
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
        uint64 rawAmount,
        uint16 priceIndex
    ) private returns (uint256) {
        Vars memory vars;

        (vars.expectedAmountIn, vars.expectedAmountOut) = _calculateAmounts(isTakingBid, priceIndex, rawAmount);
        vars.expectedTakerFee = Math.divide(vars.expectedAmountOut * Constants.TAKE_FEE, Constants.FEE_PRECISION, true);
        vars.beforePayerQuoteBalance = quoteToken.balanceOf(address(this));
        vars.beforePayerBaseBalance = baseToken.balanceOf(address(this));
        vars.beforeTakerQuoteBalance = quoteToken.balanceOf(Constants.USER_B);
        vars.beforeTakerBaseBalance = baseToken.balanceOf(Constants.USER_B);

        vm.expectEmit(true, true, true, true);
        emit TakeOrder({
            payer: address(this),
            user: Constants.USER_B,
            rawAmount: rawAmount,
            priceIndex: priceIndex,
            options: isTakingBid ? 0 : 1
        });
        uint256 orderIndex = market.limitOrder(
            Constants.USER_B,
            priceIndex,
            isTakingBid ? 0 : rawAmount,
            isTakingBid ? vars.expectedAmountIn : 0,
            isTakingBid ? 0 : 1,
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
        return orderIndex;
    }

    function _checkTakeOrders(
        bool isTakingBid,
        uint16 priceIndex,
        Order[] memory expectedTakeOrders,
        uint64 overflowAmount
    ) private returns (uint256) {
        Vars memory vars;
        for (uint256 i = 0; i < expectedTakeOrders.length; i++) {
            vars.rawAmount += expectedTakeOrders[i].rawAmount;
            (uint256 expectedAmountIn, uint256 expectedAmountOut) = _calculateAmounts(
                isTakingBid,
                expectedTakeOrders[i].priceIndex,
                expectedTakeOrders[i].rawAmount
            );
            vars.expectedAmountIn += expectedAmountIn;
            vars.expectedAmountOut += expectedAmountOut;
        }
        vars.expectedTakerFee = Math.divide(vars.expectedAmountOut * Constants.TAKE_FEE, Constants.FEE_PRECISION, true);
        if (overflowAmount > 0) {
            vars.rawAmount += overflowAmount;
            vars.expectedAmountIn += isTakingBid
                ? market.rawToBase(overflowAmount, priceIndex, true)
                : market.rawToQuote(overflowAmount);
        }
        vars.beforePayerQuoteBalance = quoteToken.balanceOf(address(this));
        vars.beforePayerBaseBalance = baseToken.balanceOf(address(this));
        vars.beforeTakerQuoteBalance = quoteToken.balanceOf(Constants.USER_B);
        vars.beforeTakerBaseBalance = baseToken.balanceOf(Constants.USER_B);

        for (uint256 i = 0; i < expectedTakeOrders.length; i++) {
            vars.snapshotId = vm.snapshot();
            vm.expectEmit(true, true, true, true);
            emit TakeOrder({
                payer: address(this),
                user: Constants.USER_B,
                rawAmount: expectedTakeOrders[i].rawAmount,
                priceIndex: expectedTakeOrders[i].priceIndex,
                options: isTakingBid ? 0 : 1
            });
            market.limitOrder(
                Constants.USER_B,
                priceIndex,
                isTakingBid ? 0 : vars.rawAmount,
                isTakingBid ? vars.expectedAmountIn : 0,
                isTakingBid ? 0 : 1,
                new bytes(0)
            );
            vm.revertTo(vars.snapshotId);
        }
        uint256 orderIndex = market.limitOrder(
            Constants.USER_B,
            priceIndex,
            isTakingBid ? 0 : vars.rawAmount,
            isTakingBid ? vars.expectedAmountIn : 0,
            isTakingBid ? 0 : 1,
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
        return orderIndex;
    }

    function testFullyFillingBid() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        // Post only using Fibonacci
        for (uint256 i = 0; i < 20; i++) {
            uint64 _rawAmount = 3 * prices[i];
            _checkMakeOrder(Constants.BID, _rawAmount, prices[i]);
        }

        // Takes
        Order[] memory expectedTakeOrders = new Order[](20);
        for (uint256 i = 0; i < 20; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[19 - i], priceIndex: prices[19 - i]});
        }
        uint256 orderIndex = _checkTakeOrders(Constants.BID, 1, expectedTakeOrders, 0);
        assertEq(orderIndex, type(uint256).max, "ERROR_ORDER_INDEX");
        for (uint256 i = 0; i < 20; i++) {
            assertEq(market.getDepth(Constants.BID, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testFullyFillingAsk() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        // Post only using Fibonacci
        for (uint256 i = 0; i < 20; i++) {
            uint64 _rawAmount = 3 * prices[i];
            _checkMakeOrder(Constants.ASK, _rawAmount, prices[i]);
        }

        // Takes
        Order[] memory expectedTakeOrders = new Order[](20);
        for (uint256 i = 0; i < 20; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[i], priceIndex: prices[i]});
        }
        uint256 orderIndex = _checkTakeOrders(Constants.ASK, type(uint16).max, expectedTakeOrders, 0);
        assertEq(orderIndex, type(uint256).max, "ERROR_ORDER_INDEX");
        for (uint256 i = 0; i < 20; i++) {
            assertEq(market.getDepth(Constants.ASK, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testPartialFillForHighestBidOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        // Post only using Fibonacci
        for (uint256 i = 0; i < 20; i++) {
            uint64 _rawAmount = 3 * prices[i];
            _checkMakeOrder(Constants.BID, _rawAmount, prices[i]);
        }

        // Takes
        Order[] memory expectedTakeOrders = new Order[](19);
        for (uint256 i = 0; i < 19; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[19 - i], priceIndex: prices[19 - i]});
        }
        uint256 orderIndex = _checkTakeOrders(Constants.BID, 1, expectedTakeOrders, 0);
        assertEq(orderIndex, type(uint256).max, "ERROR_ORDER_INDEX");
        assertEq(market.getDepth(Constants.BID, prices[0]), 3 * prices[0], "ERROR_ORDER_AMOUNT");
        for (uint256 i = 1; i < 20; i++) {
            assertEq(market.getDepth(Constants.BID, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testPartialFillForLowestAskOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        // Post only using Fibonacci
        for (uint256 i = 0; i < 20; i++) {
            uint64 _rawAmount = 3 * prices[i];
            _checkMakeOrder(Constants.ASK, _rawAmount, prices[i]);
        }

        // Takes
        Order[] memory expectedTakeOrders = new Order[](19);
        for (uint256 i = 0; i < 19; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[i], priceIndex: prices[i]});
        }
        uint256 orderIndex = _checkTakeOrders(Constants.ASK, type(uint16).max, expectedTakeOrders, 0);
        assertEq(orderIndex, type(uint256).max, "ERROR_ORDER_INDEX");
        for (uint256 i = 0; i < 19; i++) {
            assertEq(market.getDepth(Constants.ASK, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
        assertEq(market.getDepth(Constants.ASK, prices[19]), 3 * prices[19], "ERROR_ORDER_AMOUNT");
    }

    function testFillAndMakeAsk() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        uint256 makeAmount = market.rawToBase(1225, 1, true);

        // Post only using Fibonacci
        for (uint256 i = 0; i < 20; i++) {
            uint64 _rawAmount = 3 * prices[i];
            _checkMakeOrder(Constants.BID, _rawAmount, prices[i]);
        }

        // Make sure to show that post-only limit orders revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.POST_ONLY));
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(Constants.USER_A, 0, 0, makeAmount, 2, new bytes(0));

        // Takes
        Order[] memory expectedTakeOrders = new Order[](20);
        for (uint256 i = 0; i < 20; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[19 - i], priceIndex: prices[19 - i]});
        }
        uint256 orderIndex = _checkTakeOrders(Constants.BID, 1, expectedTakeOrders, 1225);
        assertEq(orderIndex, 0, "ERROR_ORDER_INDEX");
        for (uint256 i = 0; i < 20; i++) {
            assertEq(market.getDepth(Constants.BID, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testFillAndMakeBid() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        uint64 makeAmount = 1225;

        // Post only using Fibonacci
        for (uint256 i = 0; i < 20; i++) {
            uint64 _rawAmount = 3 * prices[i];
            _checkMakeOrder(Constants.ASK, _rawAmount, prices[i]);
        }

        // Make sure to show that post-only limit orders revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.POST_ONLY));
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            type(uint16).max,
            makeAmount,
            0,
            3,
            new bytes(0)
        );

        // Takes
        Order[] memory expectedTakeOrders = new Order[](20);
        for (uint256 i = 0; i < 20; i++) {
            expectedTakeOrders[i] = Order({rawAmount: 3 * prices[i], priceIndex: prices[i]});
        }
        uint256 orderIndex = _checkTakeOrders(Constants.ASK, type(uint16).max, expectedTakeOrders, 1225);
        assertEq(orderIndex, 0, "ERROR_ORDER_INDEX");
        for (uint256 i = 0; i < 20; i++) {
            assertEq(market.getDepth(Constants.ASK, prices[i]), 0, "ERROR_ORDER_AMOUNT");
        }
    }

    function testHighestBidPriceAfterFullyFillingBid() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(Constants.USER_A, 7, 2, 0, 1, new bytes(0));
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(Constants.USER_A, 7, 3, 0, 1, new bytes(0));
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(Constants.USER_A, 5, 2, 0, 1, new bytes(0));
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(Constants.USER_A, 3, 2, 0, 1, new bytes(0));
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(Constants.USER_A, 1, 2, 0, 1, new bytes(0));

        assertEq(market.bestPriceIndex(Constants.BID), 7);
        market.limitOrder(
            Constants.USER_A,
            1,
            0,
            market.rawToBase(2, 7, true) + market.rawToBase(3, 7, true) + market.rawToBase(1, 5, true),
            0,
            new bytes(0)
        );
        assertEq(market.bestPriceIndex(Constants.BID), 5);
        assertEq(market.getDepth(Constants.BID, 5), 1, "ERROR_ORDER_AMOUNT");
        vm.prank(Constants.USER_A);
        market.cancel(Constants.USER_A, _toArray(OrderKey({isBid: Constants.BID, priceIndex: 3, orderIndex: 0})));
        assertEq(market.bestPriceIndex(Constants.BID), 5);
        market.limitOrder(
            Constants.USER_A,
            1,
            0,
            market.rawToBase(1, 5, true) + market.rawToBase(1, 1, true),
            0,
            new bytes(0)
        );
        assertEq(market.getDepth(Constants.BID, 1), 1, "ERROR_ORDER_AMOUNT");
        assertEq(market.bestPriceIndex(Constants.BID), 1);
    }

    function testLowestAskPriceAfterFullyFillingAsk() public {
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
            1,
            0,
            market.rawToBase(3, 1, true),
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
        market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            7,
            0,
            market.rawToBase(2, 7, true),
            0,
            new bytes(0)
        );

        assertEq(market.bestPriceIndex(Constants.ASK), 1);
        market.limitOrder(Constants.USER_A, 7, 6, 0, 1, new bytes(0));
        assertEq(market.bestPriceIndex(Constants.ASK), 3);
        assertEq(market.getDepth(Constants.ASK, 3), 1, "ERROR_ORDER_AMOUNT");
        vm.prank(Constants.USER_A);
        market.cancel(Constants.USER_A, _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 5, orderIndex: 0})));
        assertEq(market.bestPriceIndex(Constants.ASK), 3);
        market.limitOrder(Constants.USER_A, 7, 2, 0, 1, new bytes(0));
        assertEq(market.getDepth(Constants.ASK, 7), 1, "ERROR_ORDER_AMOUNT");
        assertEq(market.bestPriceIndex(Constants.ASK), 7);
    }

    function testLargeBidOrderFlow() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < vm.envOr("LARGE_ORDER_COUNT", Constants.LARGE_ORDER_COUNT); i++) {
            // Make
            uint256 orderIndex = _checkMakeOrder(Constants.BID, 777, priceIndex, i);
            assertEq(orderIndex, i, "ERROR_ORDER_INDEX");

            // Take
            orderIndex = _checkTakeOrder(Constants.BID, 777, priceIndex);
            assertEq(orderIndex, type(uint256).max, "ERROR_ORDER_INDEX");
        }
    }

    function testLargeAskOrderFlow() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < vm.envOr("LARGE_ORDER_COUNT", Constants.LARGE_ORDER_COUNT); i++) {
            // Make
            uint256 orderIndex = _checkMakeOrder(Constants.ASK, 777, priceIndex, i);
            assertEq(orderIndex, i, "ERROR_ORDER_INDEX");

            // Take
            orderIndex = _checkTakeOrder(Constants.ASK, 777, priceIndex);
            assertEq(orderIndex, type(uint256).max, "ERROR_ORDER_INDEX");
        }
    }

    function testFullyHorizontalFillingBid() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < Constants.MAX_ORDER; i++) {
            // Make
            uint256 orderIndex = _checkMakeOrder(Constants.BID, 777, priceIndex, i);
            assertEq(orderIndex, i, "ERROR_ORDER_INDEX");
        }
        // Take all
        _checkTakeOrder(Constants.BID, 777 * uint64(Constants.MAX_ORDER), priceIndex);
    }

    function testFullyHorizontalFillingAsk() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < Constants.MAX_ORDER; i++) {
            // Make
            uint256 orderIndex = _checkMakeOrder(Constants.ASK, 777, priceIndex, i);
            assertEq(orderIndex, i, "ERROR_ORDER_INDEX");
        }
        // Take all
        _checkTakeOrder(Constants.ASK, 777 * uint64(Constants.MAX_ORDER), priceIndex);
    }

    function testVerticalBidOrderFlowWithR1001() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;

        Order[] memory expectedTakeOrders = new Order[](313);
        for (uint16 i = 0; i < 313; i++) {
            _checkMakeOrder(Constants.BID, rawAmount, priceIndex);
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.BID, 0, expectedTakeOrders, 0);
    }

    function testVerticalAskOrderFlowWithR1001() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;

        Order[] memory expectedTakeOrders = new Order[](313);
        for (uint16 i = 0; i < 313; i++) {
            _checkMakeOrder(Constants.ASK, rawAmount, priceIndex);
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.ASK, type(uint16).max, expectedTakeOrders, 0);
    }

    function testVerticalBidOrderFlowWithR101() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE, 101 * 10**16);

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;

        Order[] memory expectedTakeOrders = new Order[](34);
        for (uint16 i = 0; i < 34; i++) {
            _checkMakeOrder(Constants.BID, rawAmount, priceIndex);
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.BID, 0, expectedTakeOrders, 0);

        expectedTakeOrders = new Order[](34);
        priceIndex = CloberPriceBook(market.priceBook()).maxPriceIndex();
        for (uint16 i = 0; i < 34; i++) {
            _checkMakeOrder(Constants.BID, rawAmount, priceIndex);
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            priceIndex -= 128;
        }
        _checkTakeOrders(Constants.BID, 0, expectedTakeOrders, 0);
    }

    function testVerticalAskOrderFlowWithR101() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE, 101 * 10**16);

        // Takes
        uint16 priceIndex = 0;
        uint64 rawAmount = 3;

        Order[] memory expectedTakeOrders = new Order[](34);
        for (uint16 i = 0; i < 34; i++) {
            _checkMakeOrder(Constants.ASK, rawAmount, priceIndex);
            expectedTakeOrders[i] = Order({rawAmount: rawAmount, priceIndex: priceIndex});
            priceIndex += 128;
        }
        _checkTakeOrders(Constants.ASK, CloberPriceBook(market.priceBook()).maxPriceIndex(), expectedTakeOrders, 0);

        expectedTakeOrders = new Order[](21);
        priceIndex = CloberPriceBook(market.priceBook()).maxPriceIndex();
        for (uint16 i = 0; i < 21; i++) {
            market.limitOrder(
                Constants.USER_A,
                priceIndex,
                0,
                3 * 10**7, // baseAmount
                0,
                new bytes(0)
            );
            // expectedRawAmount: price * baseAmount * _basePrecisionComplement / quoteUnit * _quotePrecisionComplement * PRICE_PRECISION
            uint256 expectedRawAmount = (market.indexToPrice(priceIndex) * 3 * 10**7 * 10**0) /
                (10**4 * 10**12 * 10**18);
            expectedTakeOrders[i] = Order({rawAmount: uint64(expectedRawAmount), priceIndex: priceIndex});
            priceIndex -= 128;
        }
        _checkTakeOrders(Constants.ASK, CloberPriceBook(market.priceBook()).maxPriceIndex(), expectedTakeOrders, 0);
    }

    function testLimitBidWithInvalidPriceIndexWithR101() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE, 101 * 10**16);

        uint64 rawAmount = 3;
        uint16 maxPriceIndex = CloberPriceBook(market.priceBook()).maxPriceIndex();

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE_INDEX));
        market.limitOrder(Constants.USER_A, maxPriceIndex + 1, rawAmount, 0, 1, new bytes(0)); // bid

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE_INDEX));
        market.limitOrder(Constants.USER_A, maxPriceIndex + 1, rawAmount, 0, 3, new bytes(0)); // bid + posyOnly
    }

    function testLimitAskWithInvalidPriceIndexWithR101() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE, 101 * 10**16);

        uint64 rawAmount = 3;
        uint16 maxPriceIndex = CloberPriceBook(market.priceBook()).maxPriceIndex();

        uint256 baseAmount = market.rawToBase(rawAmount, maxPriceIndex, true);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE_INDEX));
        market.limitOrder(Constants.USER_A, maxPriceIndex + 1, 0, baseAmount, 0, new bytes(0)); // ask

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE_INDEX));
        market.limitOrder(Constants.USER_A, maxPriceIndex + 1, 0, baseAmount, 2, new bytes(0)); // ask + posyOnly
    }
}
