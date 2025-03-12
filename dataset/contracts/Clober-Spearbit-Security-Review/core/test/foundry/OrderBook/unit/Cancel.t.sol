// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../../contracts/interfaces/CloberMarketSwapCallbackReceiver.sol";
import "../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../contracts/mocks/MockPriceBook.sol";
import "../../../../contracts/MarketFactory.sol";
import "../../../../contracts/OrderBook.sol";
import "./Constants.sol";

contract OrderBookCancelUnitTest is Test, CloberMarketSwapCallbackReceiver {
    using OrderKeyUtils for OrderKey;
    event CancelOrder(address indexed user, uint64 rawAmount, uint256 orderIndex, uint16 priceIndex, bool isBid);
    event ClaimOrder(
        address indexed claimer,
        address indexed user,
        uint64 rawAmount,
        uint256 bountyAmount,
        uint256 orderIndex,
        uint16 priceIndex,
        bool isBase
    );

    struct Return {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 refundBounty;
    }

    uint256 constant FAIL_AMOUNT = 123535 * 1 gwei;

    uint256 receivedEthers;
    MockQuoteToken quoteToken;
    MockBaseToken baseToken;
    OrderBook orderBook;
    OrderNFT orderToken;

    function setUp() public {
        quoteToken = new MockQuoteToken();
        baseToken = new MockBaseToken();
        receivedEthers = 0;
    }

    receive() external payable {
        if (msg.value == FAIL_AMOUNT) {
            revert("");
        }
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

    function _createPostOnlyOrder(
        bool isBid,
        uint16 priceIndex,
        uint64 rawAmount
    ) private returns (uint256) {
        if (isBid) {
            return
                orderBook.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}({
                    user: Constants.MAKER,
                    priceIndex: priceIndex,
                    rawAmount: rawAmount,
                    baseAmount: 0,
                    options: 3,
                    data: new bytes(0)
                });
        } else {
            return
                orderBook.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}({
                    user: Constants.MAKER,
                    priceIndex: priceIndex,
                    rawAmount: 0,
                    baseAmount: orderBook.rawToBase(rawAmount, priceIndex, true),
                    options: 2,
                    data: new bytes(0)
                });
        }
    }

    function _toArray(OrderKey memory orderKey) private pure returns (OrderKey[] memory) {
        OrderKey[] memory ids = new OrderKey[](1);
        ids[0] = orderKey;
        return ids;
    }

    function testCancelBid() public {
        _createOrderBook(0, 0);

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);

        uint256 amountOut = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        uint256 beforeETHBalance = Constants.MAKER.balance;
        uint256 beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        OrderKey memory orderKey = OrderKey({
            isBid: Constants.BID,
            priceIndex: Constants.PRICE_INDEX,
            orderIndex: orderIndex
        });
        vm.expectCall(address(orderToken), abi.encodeCall(CloberOrderNFT.onBurn, (orderKey.encode())));
        vm.expectEmit(true, true, true, true);
        emit CancelOrder(Constants.MAKER, Constants.RAW_AMOUNT, orderIndex, Constants.PRICE_INDEX, Constants.BID);
        vm.prank(Constants.MAKER);
        orderBook.cancel(Constants.MAKER, _toArray(orderKey));
        assertEq(quoteToken.balanceOf(Constants.MAKER) - beforeQuoteBalance, amountOut, "ERROR_QUOTE_BALANCE");
        assertEq(
            Constants.MAKER.balance - beforeETHBalance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY_BALANCE"
        );
        assertEq(beforeNFTBalance - orderToken.balanceOf(Constants.MAKER), 1, "ERROR_NFT_BALANCE");
        uint256 tokenId = orderToken.encodeId(orderKey);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderToken.ownerOf(tokenId);
    }

    function testCancelAsk() public {
        _createOrderBook(0, 0);

        uint256 orderIndex = _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);

        uint256 amountOut = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false);
        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        uint256 beforeETHBalance = Constants.MAKER.balance;
        uint256 beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        OrderKey memory orderKey = OrderKey({
            isBid: Constants.ASK,
            priceIndex: Constants.PRICE_INDEX,
            orderIndex: orderIndex
        });
        vm.expectCall(address(orderToken), abi.encodeCall(CloberOrderNFT.onBurn, (orderKey.encode())));
        vm.expectEmit(true, true, true, true);
        emit CancelOrder(Constants.MAKER, Constants.RAW_AMOUNT, orderIndex, Constants.PRICE_INDEX, Constants.ASK);
        vm.prank(Constants.MAKER);
        orderBook.cancel(Constants.MAKER, _toArray(orderKey));
        assertEq(baseToken.balanceOf(Constants.MAKER) - beforeBaseBalance, amountOut, "ERROR_BASE_BALANCE");
        assertEq(
            Constants.MAKER.balance - beforeETHBalance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY_BALANCE"
        );
        assertEq(beforeNFTBalance - orderToken.balanceOf(Constants.MAKER), 1, "ERROR_NFT_BALANCE");
        uint256 tokenId = orderToken.encodeId(orderKey);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderToken.ownerOf(tokenId);
    }

    function testCancelByOrderToken() public {
        _createOrderBook(0, 0);

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);

        uint256 amountOut = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        uint256 beforeETHBalance = Constants.MAKER.balance;
        uint256 beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        OrderKey memory orderKey = OrderKey({
            isBid: Constants.BID,
            priceIndex: Constants.PRICE_INDEX,
            orderIndex: orderIndex
        });
        vm.expectCall(address(orderToken), abi.encodeCall(CloberOrderNFT.onBurn, (orderKey.encode())));
        vm.expectEmit(true, true, true, true);
        emit CancelOrder(Constants.MAKER, Constants.RAW_AMOUNT, orderIndex, Constants.PRICE_INDEX, Constants.BID);
        vm.prank(address(orderToken));
        orderBook.cancel(Constants.MAKER, _toArray(orderKey));
        assertEq(quoteToken.balanceOf(Constants.MAKER) - beforeQuoteBalance, amountOut, "ERROR_QUOTE_BALANCE");
        assertEq(
            Constants.MAKER.balance - beforeETHBalance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY_BALANCE"
        );
        assertEq(beforeNFTBalance - orderToken.balanceOf(Constants.MAKER), 1, "ERROR_NFT_BALANCE");
        uint256 tokenId = orderToken.encodeId(orderKey);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderToken.ownerOf(tokenId);
    }

    function testDuplicatedCancel() public {
        _createOrderBook(0, 0);

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);

        uint256 beforeETHBalance = Constants.MAKER.balance;
        vm.prank(Constants.MAKER);
        orderBook.cancel(
            Constants.MAKER,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );
        assertEq(Constants.MAKER.balance - beforeETHBalance, Constants.CLAIM_BOUNTY * 1 gwei, "CLAIM_BOUNTY_BALANCE");

        beforeETHBalance = Constants.MAKER.balance;
        vm.prank(Constants.MAKER);
        orderBook.cancel(
            Constants.MAKER,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );
        assertEq(Constants.MAKER.balance - beforeETHBalance, 0, "CLAIM_BOUNTY_BALANCE");
    }

    function testCancelMiddlePrice() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID, 1, Constants.RAW_AMOUNT);
        uint256 orderIndex3 = _createPostOnlyOrder(Constants.BID, 3, Constants.RAW_AMOUNT);
        uint256 orderIndex5 = _createPostOnlyOrder(Constants.BID, 5, Constants.RAW_AMOUNT);

        assertEq(orderBook.bestPriceIndex(Constants.BID), 5, "ERROR_BID_PRICE");

        vm.prank(Constants.MAKER);
        orderBook.cancel(
            Constants.MAKER,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 3, orderIndex: orderIndex3}))
        );

        assertEq(orderBook.bestPriceIndex(Constants.BID), 5, "ERROR_BID_PRICE");

        vm.prank(Constants.MAKER);
        orderBook.cancel(
            Constants.MAKER,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 5, orderIndex: orderIndex5}))
        );

        assertEq(orderBook.bestPriceIndex(Constants.BID), 1, "ERROR_BID_PRICE");
    }

    function testCancelEmptyInput() public {
        _createOrderBook(0, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        orderBook.cancel(address(this), new OrderKey[](0));
    }

    function testValueTransferFailed() public {
        _createOrderBook(0, 0);

        uint256 orderIndex = orderBook.limitOrder{value: FAIL_AMOUNT}({
            user: address(this),
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: 3,
            data: new bytes(0)
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.FAILED_TO_SEND_VALUE));
        orderBook.cancel(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );
    }

    function testCancelAccess() public {
        _createOrderBook(0, 0);

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderBook.cancel(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );
    }

    function testCancelWhenOrderIndexIsOutOfRange() public {
        _createOrderBook(0, 0);

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_ID));
        orderBook.cancel(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex + 1}))
        );
    }

    function testCancelReplacedBidOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);

        // Fill all the orders
        for (uint256 i = 0; i < Constants.MAX_ORDER - 1; i++) {
            _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);
        }
        // Take the first order
        orderBook.limitOrder({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT * 2, Constants.PRICE_INDEX, true),
            options: 0,
            data: new bytes(0)
        });
        // replace the first order
        _createPostOnlyOrder(Constants.BID, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);

        uint256 expectedClaimAmount = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false);
        uint256 expectedMakerFee = Math.divide(expectedClaimAmount * Constants.MAKE_FEE, Constants.FEE_PRECISION, true);
        // calculate taker fee that protocol gained
        uint256 expectedTakerFee = (orderBook.rawToQuote(Constants.RAW_AMOUNT) * Constants.TAKE_FEE) /
            Constants.FEE_PRECISION;

        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        uint256 beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        uint256 beforeMakerBalance = Constants.MAKER.balance;
        (uint256 beforeQuoteFeeBalance, uint256 beforeBaseFeeBalance) = orderBook.getFeeBalance();

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.BID, Constants.PRICE_INDEX, orderIndex).encode()))
        );
        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            Constants.MAKER,
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            Constants.CLAIM_BOUNTY * 1 gwei,
            orderIndex,
            Constants.PRICE_INDEX,
            Constants.BID
        );
        vm.startPrank(Constants.MAKER);
        orderBook.cancel(
            Constants.MAKER,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );
        vm.stopPrank();

        (uint256 afterQuoteFeeBalance, uint256 afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(
            baseToken.balanceOf(Constants.MAKER) - beforeBaseBalance,
            expectedClaimAmount - expectedMakerFee,
            "ERROR_BASE_BALANCE"
        );
        assertEq(afterQuoteFeeBalance - beforeQuoteFeeBalance, expectedTakerFee, "PROTOCOL_FEE_QUOTE_BALANCE");
        assertEq(afterBaseFeeBalance - beforeBaseFeeBalance, expectedMakerFee, "PROTOCOL_FEE_BASE_BALANCE");
        assertEq(Constants.MAKER.balance - beforeMakerBalance, Constants.CLAIM_BOUNTY * 1 gwei, "CLAIM_BOUNTY_BALANCE");
        assertEq(beforeNFTBalance, orderToken.balanceOf(Constants.MAKER) + 1, "ERROR_NFT_BALANCE");
    }

    function testCancelReplacedAskOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint256 orderIndex = _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);

        // Fill all the orders
        for (uint256 i = 0; i < Constants.MAX_ORDER - 1; i++) {
            _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);
        }
        // Take the first order
        orderBook.limitOrder({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: Constants.RAW_AMOUNT * 2,
            baseAmount: 0,
            options: 1,
            data: new bytes(0)
        });
        // replace the first order
        _createPostOnlyOrder(Constants.ASK, Constants.PRICE_INDEX, Constants.RAW_AMOUNT);

        uint256 expectedClaimAmount = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        uint256 expectedMakerFee = Math.divide(expectedClaimAmount * Constants.MAKE_FEE, Constants.FEE_PRECISION, true);
        // calculate taker fee that protocol gained
        uint256 expectedTakerFee = (orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false) *
            Constants.TAKE_FEE) / Constants.FEE_PRECISION;

        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        uint256 beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        uint256 beforeMakerBalance = Constants.MAKER.balance;
        (uint256 beforeQuoteFeeBalance, uint256 beforeBaseFeeBalance) = orderBook.getFeeBalance();

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.ASK, Constants.PRICE_INDEX, orderIndex).encode()))
        );
        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            Constants.MAKER,
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            Constants.CLAIM_BOUNTY * 1 gwei,
            orderIndex,
            Constants.PRICE_INDEX,
            Constants.ASK
        );
        vm.startPrank(Constants.MAKER);
        orderBook.cancel(
            Constants.MAKER,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );
        vm.stopPrank();

        (uint256 afterQuoteFeeBalance, uint256 afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(
            quoteToken.balanceOf(Constants.MAKER) - beforeQuoteBalance,
            expectedClaimAmount - expectedMakerFee,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(afterQuoteFeeBalance - beforeQuoteFeeBalance, expectedMakerFee, "PROTOCOL_FEE_QUOTE_BALANCE");
        assertEq(afterBaseFeeBalance - beforeBaseFeeBalance, expectedTakerFee, "PROTOCOL_FEE_BASE_BALANCE");
        assertEq(Constants.MAKER.balance - beforeMakerBalance, Constants.CLAIM_BOUNTY * 1 gwei, "CLAIM_BOUNTY_BALANCE");
        assertEq(beforeNFTBalance, orderToken.balanceOf(Constants.MAKER) + 1, "ERROR_NFT_BALANCE");
    }
}
