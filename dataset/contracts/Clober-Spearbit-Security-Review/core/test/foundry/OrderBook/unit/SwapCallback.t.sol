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

contract OrderBookSwapCallbackUnitTest is Test, CloberMarketSwapCallbackReceiver {
    function cloberMarketSwapCallback(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata data
    ) external payable {
        tokenIn;
        tokenOut;
        amountIn;
        amountOut;
        data;
    }

    MockQuoteToken quoteToken;
    MockBaseToken baseToken;
    OrderBook orderBook;
    OrderNFT orderToken;

    function setUp() public {
        quoteToken = new MockQuoteToken();
        baseToken = new MockBaseToken();

        orderToken = new OrderNFT(address(this), address(this));
        orderBook = new OrderBook(
            address(orderToken),
            address(quoteToken),
            address(baseToken),
            10**4,
            0,
            0,
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

    function testInsufficientBalance() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INSUFFICIENT_BALANCE));
        orderBook.limitOrder(Constants.MAKER, Constants.PRICE_INDEX, 10, 0, 1, new bytes(0));
    }
}
