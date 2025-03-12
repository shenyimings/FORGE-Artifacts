// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../contracts/mocks/MockPriceBook.sol";
import "../../../../contracts/OrderNFT.sol";
import "../../../../contracts/OrderBook.sol";
import "../utils/MockingFactoryTest.sol";
import "./Constants.sol";

contract OrderBookCollectFeesUnitTest is Test, CloberMarketSwapCallbackReceiver, MockingFactoryTest {
    MockQuoteToken quoteToken;
    MockBaseToken baseToken;
    OrderBook orderBook;
    OrderNFT orderToken;

    function cloberMarketSwapCallback(
        address tokenIn,
        address,
        uint256 amountIn,
        uint256,
        bytes calldata
    ) external payable {
        IERC20(tokenIn).transfer(msg.sender, amountIn);
    }

    function setUp() public {
        _host = address(0x999);
        quoteToken = new MockQuoteToken();
        baseToken = new MockBaseToken();

        orderToken = new OrderNFT(address(this), address(this));
        orderBook = new OrderBook(
            address(orderToken),
            address(quoteToken),
            address(baseToken),
            10**4,
            int24(Constants.MAKE_FEE),
            Constants.TAKE_FEE,
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
        uint64 rawAmount = 10000;

        uint256 orderIndex = orderBook.limitOrder({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: rawAmount,
            baseAmount: 0,
            options: 3,
            data: new bytes(0)
        });
        orderBook.limitOrder({
            user: Constants.TAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(rawAmount, Constants.PRICE_INDEX, true),
            options: 0,
            data: new bytes(0)
        });

        OrderKey[] memory ids = new OrderKey[](1);
        ids[0] = OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex});
        orderBook.claim(address(this), ids);
    }

    struct BalanceInfo {
        uint128 quote;
        uint128 base;
        uint256 quoteReadyToBeDeliveredToHost;
        uint256 quoteReadyToBeDeliveredToDao;
        uint256 baseReadyToBeDeliveredToHost;
        uint256 baseReadyToBeDeliveredToDao;
        uint256 hostQuote;
        uint256 hostBase;
        uint256 daoQuote;
        uint256 daoBase;
        uint256 marketQuote;
        uint256 marketBase;
    }

    function _getBalanceInfo() internal view returns (BalanceInfo memory info) {
        (info.quote, info.base) = orderBook.getFeeBalance();
        info.quoteReadyToBeDeliveredToHost = orderBook.uncollectedHostFees(address(quoteToken));
        info.quoteReadyToBeDeliveredToDao = orderBook.uncollectedProtocolFees(address(quoteToken));
        info.baseReadyToBeDeliveredToHost = orderBook.uncollectedHostFees(address(baseToken));
        info.baseReadyToBeDeliveredToDao = orderBook.uncollectedProtocolFees(address(baseToken));
        info.hostQuote = quoteToken.balanceOf(_host);
        info.hostBase = baseToken.balanceOf(_host);
        info.daoQuote = quoteToken.balanceOf(daoTreasury);
        info.daoBase = baseToken.balanceOf(daoTreasury);
        info.marketQuote = quoteToken.balanceOf(address(orderBook));
        info.marketBase = baseToken.balanceOf(address(orderBook));
        return info;
    }

    function testCollectFeesQuoteToHost() public {
        BalanceInfo memory beforeInfo = _getBalanceInfo();
        uint256 expectedDaoFee = Math.divide(beforeInfo.quote * Constants.DAO_FEE, Constants.FEE_PRECISION, true);
        uint256 expectedHostFee = beforeInfo.quote - expectedDaoFee;

        orderBook.collectFees(address(quoteToken), _host);

        BalanceInfo memory afterInfo = _getBalanceInfo();
        assertEq(afterInfo.quote, 0, "QUOTE");
        assertEq(beforeInfo.base, afterInfo.base, "BASE");
        assertEq(afterInfo.quoteReadyToBeDeliveredToHost, 0, "QUOTE_READY_TO_BE_DELIVERED_TO_HOST");
        assertEq(afterInfo.quoteReadyToBeDeliveredToDao, expectedDaoFee, "QUOTE_READY_TO_BE_DELIVERED_TO_DAO");
        assertEq(afterInfo.baseReadyToBeDeliveredToHost, 0, "BASE_READY_TO_BE_DELIVERED_TO_HOST");
        assertEq(afterInfo.baseReadyToBeDeliveredToDao, 0, "BASE_READY_TO_BE_DELIVERED_TO_DAO");
        assertEq(afterInfo.hostQuote - beforeInfo.hostQuote, expectedHostFee, "HOST_QUOTE");
        assertEq(afterInfo.hostBase, beforeInfo.hostBase, "HOST_BASE");
        assertEq(afterInfo.daoQuote, beforeInfo.daoQuote, "DAO_QUOTE");
        assertEq(afterInfo.daoBase, beforeInfo.daoBase, "DAO_BASE");
        assertEq(beforeInfo.marketQuote - afterInfo.marketQuote, expectedHostFee, "MARKET_QUOTE");
        assertEq(beforeInfo.marketBase, afterInfo.marketBase, "MARKET_QUOTE");
    }

    function testCollectFeesQuoteToDaoTreasury() public {
        BalanceInfo memory beforeInfo = _getBalanceInfo();
        uint256 expectedDaoFee = Math.divide(beforeInfo.quote * Constants.DAO_FEE, Constants.FEE_PRECISION, true);
        uint256 expectedHostFee = beforeInfo.quote - expectedDaoFee;

        orderBook.collectFees(address(quoteToken), daoTreasury);

        BalanceInfo memory afterInfo = _getBalanceInfo();
        assertEq(afterInfo.quote, 0, "QUOTE");
        assertEq(beforeInfo.base, afterInfo.base, "BASE");
        assertEq(afterInfo.quoteReadyToBeDeliveredToHost, expectedHostFee, "QUOTE_READY_TO_BE_DELIVERED_TO_HOST");
        assertEq(afterInfo.quoteReadyToBeDeliveredToDao, 0, "QUOTE_READY_TO_BE_DELIVERED_TO_DAO");
        assertEq(afterInfo.baseReadyToBeDeliveredToHost, 0, "BASE_READY_TO_BE_DELIVERED_TO_HOST");
        assertEq(afterInfo.baseReadyToBeDeliveredToDao, 0, "BASE_READY_TO_BE_DELIVERED_TO_DAO");
        assertEq(afterInfo.hostQuote, beforeInfo.hostQuote, "HOST_QUOTE");
        assertEq(afterInfo.hostBase, beforeInfo.hostBase, "HOST_BASE");
        assertEq(afterInfo.daoQuote - beforeInfo.daoQuote, expectedDaoFee, "DAO_QUOTE");
        assertEq(afterInfo.daoBase, beforeInfo.daoBase, "DAO_BASE");
        assertEq(beforeInfo.marketQuote - afterInfo.marketQuote, expectedDaoFee, "MARKET_QUOTE");
        assertEq(beforeInfo.marketBase, afterInfo.marketBase, "MARKET_QUOTE");
    }

    function testCollectFeesBaseToHost() public {
        BalanceInfo memory beforeInfo = _getBalanceInfo();
        uint256 expectedDaoFee = Math.divide(beforeInfo.base * Constants.DAO_FEE, Constants.FEE_PRECISION, true);
        uint256 expectedHostFee = beforeInfo.base - expectedDaoFee;

        orderBook.collectFees(address(baseToken), _host);

        BalanceInfo memory afterInfo = _getBalanceInfo();
        assertEq(beforeInfo.quote, afterInfo.quote, "QUOTE");
        assertEq(afterInfo.base, 0, "BASE");
        assertEq(afterInfo.quoteReadyToBeDeliveredToHost, 0, "QUOTE_READY_TO_BE_DELIVERED_TO_HOST");
        assertEq(afterInfo.quoteReadyToBeDeliveredToDao, 0, "QUOTE_READY_TO_BE_DELIVERED_TO_DAO");
        assertEq(afterInfo.baseReadyToBeDeliveredToHost, 0, "BASE_READY_TO_BE_DELIVERED_TO_HOST");
        assertEq(afterInfo.baseReadyToBeDeliveredToDao, expectedDaoFee, "BASE_READY_TO_BE_DELIVERED_TO_DAO");
        assertEq(afterInfo.hostQuote, beforeInfo.hostQuote, "HOST_QUOTE");
        assertEq(afterInfo.hostBase - beforeInfo.hostBase, expectedHostFee, "HOST_BASE");
        assertEq(afterInfo.daoQuote, beforeInfo.daoQuote, "DAO_QUOTE");
        assertEq(afterInfo.daoBase, beforeInfo.daoBase, "DAO_BASE");
        assertEq(beforeInfo.marketQuote, afterInfo.marketQuote, "MARKET_QUOTE");
        assertEq(beforeInfo.marketBase - afterInfo.marketBase, expectedHostFee, "MARKET_QUOTE");
    }

    function testCollectFeesBaseToDaoTreasury() public {
        BalanceInfo memory beforeInfo = _getBalanceInfo();
        uint256 expectedDaoFee = Math.divide(beforeInfo.base * Constants.DAO_FEE, Constants.FEE_PRECISION, true);
        uint256 expectedHostFee = beforeInfo.base - expectedDaoFee;

        orderBook.collectFees(address(baseToken), daoTreasury);

        BalanceInfo memory afterInfo = _getBalanceInfo();
        assertEq(beforeInfo.quote, afterInfo.quote, "QUOTE");
        assertEq(afterInfo.base, 0, "BASE");
        assertEq(afterInfo.quoteReadyToBeDeliveredToHost, 0, "QUOTE_READY_TO_BE_DELIVERED_TO_HOST");
        assertEq(afterInfo.quoteReadyToBeDeliveredToDao, 0, "QUOTE_READY_TO_BE_DELIVERED_TO_DAO");
        assertEq(afterInfo.baseReadyToBeDeliveredToHost, expectedHostFee, "BASE_READY_TO_BE_DELIVERED_TO_HOST");
        assertEq(afterInfo.baseReadyToBeDeliveredToDao, 0, "BASE_READY_TO_BE_DELIVERED_TO_DAO");
        assertEq(afterInfo.hostQuote, beforeInfo.hostQuote, "HOST_QUOTE");
        assertEq(afterInfo.hostBase, beforeInfo.hostBase, "HOST_BASE");
        assertEq(afterInfo.daoQuote, beforeInfo.daoQuote, "DAO_QUOTE");
        assertEq(afterInfo.daoBase - beforeInfo.daoBase, expectedDaoFee, "DAO_BASE");
        assertEq(beforeInfo.marketQuote, afterInfo.marketQuote, "MARKET_QUOTE");
        assertEq(beforeInfo.marketBase - afterInfo.marketBase, expectedDaoFee, "MARKET_QUOTE");
    }

    function testCollectFeesWithWrongToken() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderBook.collectFees(address(0x123), _host);
    }

    function testCollectFeesWithWrongDestination() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderBook.collectFees(address(quoteToken), address(0x123));
    }
}
