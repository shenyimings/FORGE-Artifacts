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
import "../utils/MockingFactoryTest.sol";
import "./Constants.sol";

contract OrderBookLimitOrderUnitTest is Test, CloberMarketSwapCallbackReceiver, MockingFactoryTest {
    using OrderKeyUtils for OrderKey;
    event MakeOrder(
        address indexed payer,
        address indexed user,
        uint64 rawAmount,
        uint32 claimBounty,
        uint256 orderIndex,
        uint16 priceIndex,
        uint8 options
    );
    event TakeOrder(address indexed payer, address indexed user, uint16 priceIndex, uint64 rawAmount, uint8 options);

    struct Return {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 refundBounty;
    }

    struct Vars {
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 beforePayerQuoteBalance;
        uint256 beforePayerBaseBalance;
        uint256 beforeTakerQuoteBalance;
        uint256 beforeOrderBookEthBalance;
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
            10**4,
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

    function _buildLimitOrderOptions(bool isBid, bool postOnly) private pure returns (uint8) {
        return (isBid ? 1 : 0) + (postOnly ? 2 : 0);
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
        Vars memory vars;

        assertTrue(orderBook.isEmpty(Constants.BID), "ERROR_NOT_EMPTY");
        vm.expectRevert();
        orderBook.bestPriceIndex(Constants.BID);

        // MakeOrder
        vars.inputAmount = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        vm.expectCall(
            address(orderToken),
            abi.encodeCall(
                CloberOrderNFT.onMint,
                (Constants.MAKER, OrderKey(Constants.BID, Constants.PRICE_INDEX, 0).encode())
            )
        );
        vm.expectEmit(true, true, true, true);
        emit MakeOrder({
            payer: address(this),
            user: Constants.MAKER,
            rawAmount: Constants.RAW_AMOUNT,
            claimBounty: uint32(Constants.CLAIM_BOUNTY),
            orderIndex: 0,
            priceIndex: Constants.PRICE_INDEX,
            options: 1 // BID
        });
        vars.beforePayerQuoteBalance = quoteToken.balanceOf(address(this));
        vars.beforeOrderBookEthBalance = address(orderBook).balance;
        uint256 orderIndex = orderBook.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildLimitOrderOptions(Constants.BID, !Constants.POST_ONLY),
            data: abi.encode(
                Return({
                    tokenIn: address(quoteToken),
                    tokenOut: address(baseToken),
                    amountIn: vars.inputAmount,
                    amountOut: 0,
                    refundBounty: 0
                })
            )
        });
        assertEq(orderIndex, 0);
        assertFalse(orderBook.isEmpty(Constants.BID), "ERROR_EMPTY");
        assertEq(orderBook.bestPriceIndex(Constants.BID), Constants.PRICE_INDEX, "ERROR_CURRENT_PRICE");
        assertEq(orderBook.getDepth(Constants.BID, Constants.PRICE_INDEX), Constants.RAW_AMOUNT, "ERROR_ORDER_AMOUNT");
        assertEq(
            address(orderBook).balance - vars.beforeOrderBookEthBalance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY"
        );
        assertEq(
            vars.beforePayerQuoteBalance - quoteToken.balanceOf(address(this)),
            vars.inputAmount,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(
            orderToken.ownerOf(orderToken.encodeId(OrderKey(Constants.BID, Constants.PRICE_INDEX, 0))),
            Constants.MAKER,
            "ERROR_NFT_OWNER"
        );

        // TakeOrder
        vars.inputAmount = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true);
        vars.outputAmount = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit TakeOrder({
            payer: address(this),
            user: Constants.TAKER,
            rawAmount: Constants.RAW_AMOUNT,
            priceIndex: Constants.PRICE_INDEX,
            options: 0 // ASK
        });
        vars.beforePayerBaseBalance = baseToken.balanceOf(address(this));
        vars.beforeTakerQuoteBalance = quoteToken.balanceOf(Constants.TAKER);
        orderIndex = orderBook.limitOrder({
            user: Constants.TAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: 0,
            baseAmount: vars.inputAmount,
            options: _buildLimitOrderOptions(Constants.ASK, !Constants.POST_ONLY),
            data: abi.encode(
                Return({
                    tokenIn: address(baseToken),
                    tokenOut: address(quoteToken),
                    amountIn: vars.inputAmount,
                    amountOut: vars.outputAmount,
                    refundBounty: 0
                })
            )
        });
        assertEq(orderIndex, type(uint256).max);
        assertEq(orderBook.getDepth(Constants.BID, Constants.PRICE_INDEX), 0, "ERROR_ORDER_AMOUNT");
        assertEq(
            quoteToken.balanceOf(Constants.TAKER) - vars.beforeTakerQuoteBalance,
            vars.outputAmount,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(
            vars.beforePayerBaseBalance - baseToken.balanceOf(address(this)),
            vars.inputAmount,
            "ERROR_BASE_BALANCE"
        );
    }

    function testEmptyLimitOrder() public {
        _createOrderBook(0, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        orderBook.limitOrder(
            address(this),
            Constants.PRICE_INDEX,
            0,
            0,
            _buildLimitOrderOptions(Constants.BID, !Constants.POST_ONLY),
            new bytes(0)
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        orderBook.limitOrder(
            address(this),
            Constants.PRICE_INDEX,
            0,
            0,
            _buildLimitOrderOptions(Constants.ASK, !Constants.POST_ONLY),
            new bytes(0)
        );
    }

    function testOverflowInBaseToRawOnMake() public {
        _createOrderBook(0, 0);

        uint256 _basePrecision = 10**baseToken.decimals();
        baseToken.mint(address(this), type(uint128).max * _basePrecision);
        uint256 balance = baseToken.balanceOf(address(this));
        uint8 options = _buildLimitOrderOptions(Constants.ASK, !Constants.POST_ONLY);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.OVERFLOW_UNDERFLOW));
        orderBook.limitOrder(address(this), Constants.PRICE_INDEX, 0, balance, options, new bytes(0));
    }

    function testOverflowInBaseToRawOnTake() public {
        _createOrderBook(0, 0);

        uint256 _quotePrecision = 10**quoteToken.decimals();
        quoteToken.mint(address(this), type(uint128).max * _quotePrecision);
        quoteToken.approve(address(this), type(uint256).max);
        orderBook.limitOrder(
            address(this),
            Constants.PRICE_INDEX,
            type(uint64).max - 1,
            0,
            _buildLimitOrderOptions(Constants.BID, !Constants.POST_ONLY),
            new bytes(0)
        );

        uint256 _basePrecision = 10**baseToken.decimals();
        baseToken.mint(address(this), type(uint128).max * _basePrecision);
        uint256 balance = baseToken.balanceOf(address(this));
        uint8 options = _buildLimitOrderOptions(Constants.ASK, !Constants.POST_ONLY);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.OVERFLOW_UNDERFLOW));
        orderBook.limitOrder(address(this), Constants.PRICE_INDEX, 0, balance, options, new bytes(0));
    }

    function testOverflowInClaimBounty() public {
        _createOrderBook(0, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.OVERFLOW_UNDERFLOW));
        orderBook.limitOrder{value: 100 ether}(
            address(this),
            Constants.PRICE_INDEX,
            Constants.RAW_AMOUNT,
            0,
            _buildLimitOrderOptions(Constants.BID, !Constants.POST_ONLY),
            new bytes(0)
        );
    }

    function testPostOnlyWhenOppositeSideHasOrderWithSamePrice() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.ASK);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.POST_ONLY));
        orderBook.limitOrder({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildLimitOrderOptions(Constants.BID, Constants.POST_ONLY),
            data: new bytes(0)
        });
    }

    function testPostOnlyBidWhenOppositeSideHasLowerAsk() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX - 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.POST_ONLY));
        orderBook.limitOrder({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildLimitOrderOptions(Constants.BID, Constants.POST_ONLY),
            data: new bytes(0)
        });
    }

    function testPostOnlyAskWhenOppositeSideHasHigherBid() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX + 1);

        uint256 amountIn = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.POST_ONLY));
        orderBook.limitOrder({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: 0,
            baseAmount: amountIn,
            options: _buildLimitOrderOptions(Constants.ASK, Constants.POST_ONLY),
            data: new bytes(0)
        });
    }

    function testQueueReplaceFail() public {
        _createOrderBook(0, 0);

        for (uint256 i = 0; i < Constants.MAX_ORDER; i++) {
            _createPostOnlyOrder(Constants.BID);
        }

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.QUEUE_REPLACE_FAILED));
        _createPostOnlyOrder(Constants.BID);
    }

    function testChangeOrderOwnerFail() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderBook.changeOrderOwner(
            OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: 0}),
            address(this)
        );
    }

    function testChangeOrderOwner() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID);

        assertEq(
            orderToken.ownerOf(orderToken.encodeId(OrderKey(Constants.BID, Constants.PRICE_INDEX, 0))),
            Constants.MAKER
        );
        vm.prank(address(orderToken));
        orderBook.changeOrderOwner(
            OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: 0}),
            address(this)
        );
        assertEq(
            orderToken.ownerOf(orderToken.encodeId(OrderKey(Constants.BID, Constants.PRICE_INDEX, 0))),
            address(this)
        );
    }

    function testAvoidFakeOptionsAsMarketOrder() public {
        _createOrderBook(0, 0);

        // MakeOrder
        vm.expectEmit(true, true, true, true);
        emit MakeOrder({
            payer: address(this),
            user: Constants.MAKER,
            rawAmount: Constants.RAW_AMOUNT,
            claimBounty: uint32(Constants.CLAIM_BOUNTY),
            orderIndex: 0,
            priceIndex: Constants.PRICE_INDEX,
            options: 1 // BID
        });
        orderBook.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: 0x80 | _buildLimitOrderOptions(Constants.BID, !Constants.POST_ONLY),
            data: new bytes(0)
        });

        // TakeOrder
        vm.expectEmit(true, true, true, true);
        emit TakeOrder({
            payer: address(this),
            user: Constants.TAKER,
            rawAmount: Constants.RAW_AMOUNT,
            priceIndex: Constants.PRICE_INDEX,
            options: 0 // ASK
        });
        orderBook.limitOrder({
            user: Constants.TAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true),
            options: 0x80 | _buildLimitOrderOptions(Constants.ASK, !Constants.POST_ONLY),
            data: new bytes(0)
        });
    }

    function testLimitBidWithInvalidPrice() public {
        _createOrderBook(0, 0);

        uint16 invalidPriceIndex = CloberPriceBook(orderBook.priceBook()).maxPriceIndex() + 1;
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE_INDEX));
        orderBook.limitOrder({
            user: Constants.MAKER,
            priceIndex: invalidPriceIndex,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: _buildLimitOrderOptions(Constants.BID, !Constants.POST_ONLY),
            data: new bytes(0)
        });
    }
}
