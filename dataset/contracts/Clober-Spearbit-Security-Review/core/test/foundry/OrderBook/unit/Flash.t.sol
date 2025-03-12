// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../contracts/mocks/MockPriceBook.sol";
import "../../../../contracts/OrderBook.sol";
import "./Constants.sol";

contract OrderBookFlashUnitTest is Test, CloberMarketFlashCallbackReceiver {
    event Flash(
        address indexed caller,
        address indexed borrower,
        uint256 quoteAmount,
        uint256 baseAmount,
        uint256 earnedQuote,
        uint256 earnedBase
    );

    uint96 private constant _QUOTE_UNIT = 10**4; // unit is 1 USDC
    uint256 private constant _INIT_AMOUNT = 1000000000;
    address private constant _BORROWER = address(0x123123);

    MockQuoteToken quoteToken;
    MockBaseToken baseToken;
    OrderBook market;

    bytes customData;

    function setUp() public {
        quoteToken = new MockQuoteToken();
        baseToken = new MockBaseToken();
        market = new OrderBook(
            address(0x123),
            address(quoteToken),
            address(baseToken),
            _QUOTE_UNIT,
            int24(Constants.MAKE_FEE),
            Constants.TAKE_FEE,
            address(this),
            address(new MockPriceBook())
        );

        quoteToken.mint(address(market), _INIT_AMOUNT * 1e6);
        baseToken.mint(address(market), _INIT_AMOUNT * 1e18);

        quoteToken.mint(address(this), 2 * _INIT_AMOUNT * 1e6);
        baseToken.mint(address(this), 2 * _INIT_AMOUNT * 1e18);
    }

    function cloberMarketFlashCallback(
        address quoteToken_,
        address baseToken_,
        uint256 quoteAmount,
        uint256 baseAmount,
        uint256 quoteFee,
        uint256 baseFee,
        bytes calldata data
    ) external {
        assertEq(IERC20(quoteToken_).balanceOf(_BORROWER), quoteAmount, "CALLBACK_QUOTE_AMOUNT");
        assertEq(IERC20(baseToken_).balanceOf(_BORROWER), baseAmount, "CALLBACK_BASE_AMOUNT");
        assertEq(address(quoteToken), quoteToken_, "CALLBACK_QUOTE_ADDRESS");
        assertEq(address(baseToken), baseToken_, "CALLBACK_BASE_ADDRESS");
        assertEq(customData, data);
        (bytes32 dataKey, bytes memory payload) = abi.decode(data, (bytes32, bytes));
        if (dataKey == bytes32("customFee")) {
            (quoteFee, baseFee) = abi.decode(payload, (uint256, uint256));
        }

        uint256 repayQuote = quoteAmount + quoteFee;
        uint256 repayBase = baseAmount + baseFee;
        IERC20(quoteToken_).transfer(msg.sender, repayQuote);
        IERC20(baseToken_).transfer(msg.sender, repayBase);
    }

    function testFlash() public {
        uint256 quoteAmount = 100 * 1e6;
        uint256 baseAmount = 100 * 1e18;
        customData = abi.encode(bytes32("hello"), new bytes(0));

        uint256 beforeThisQuote = quoteToken.balanceOf(address(this));
        uint256 beforeThisBase = baseToken.balanceOf(address(this));
        uint256 beforeMarketQuote = quoteToken.balanceOf(address(market));
        uint256 beforeMarketBase = baseToken.balanceOf(address(market));

        uint256 expectedQuoteFee = (quoteAmount * Constants.TAKE_FEE) / Constants.FEE_PRECISION;
        uint256 expectedBaseFee = (baseAmount * Constants.TAKE_FEE) / Constants.FEE_PRECISION;

        vm.expectEmit(true, true, true, true);
        emit Flash(address(this), _BORROWER, quoteAmount, baseAmount, expectedQuoteFee, expectedBaseFee);
        market.flash(_BORROWER, quoteAmount, baseAmount, customData);

        uint256 thisQuoteDiff = beforeThisQuote - quoteToken.balanceOf(address(this));
        uint256 thisBaseDiff = beforeThisBase - baseToken.balanceOf(address(this));
        uint256 marketQuoteDiff = quoteToken.balanceOf(address(market)) - beforeMarketQuote;
        uint256 marketBaseDiff = baseToken.balanceOf(address(market)) - beforeMarketBase;

        assertEq(thisQuoteDiff, quoteAmount + expectedQuoteFee, "THIS_QUOTE_AMOUNT");
        assertEq(thisBaseDiff, baseAmount + expectedBaseFee, "THIS_BASE_AMOUNT");
        assertEq(quoteToken.balanceOf(_BORROWER), quoteAmount, "BORROWER_QUOTE_AMOUNT");
        assertEq(baseToken.balanceOf(_BORROWER), baseAmount, "BORROWER_BASE_AMOUNT");
        assertEq(marketQuoteDiff, expectedQuoteFee, "MARKET_QUOTE_AMOUNT");
        assertEq(marketBaseDiff, expectedBaseFee, "MARKET_BASE_AMOUNT");
        (uint128 quoteFeeBalance, uint128 baseFeeBalance) = market.getFeeBalance();
        assertEq(quoteFeeBalance, expectedQuoteFee, "PROTOCOL_FEE_QUOTE_AMOUNT");
        assertEq(baseFeeBalance, expectedBaseFee, "PROTOCOL_FEE_BASE_AMOUNT");
    }

    function testFlashMaxAmount() public {
        uint256 quoteBalance = quoteToken.balanceOf(address(market));
        uint256 baseBalance = baseToken.balanceOf(address(market));
        customData = abi.encode(bytes32("hello"), new bytes(0));

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        market.flash(_BORROWER, quoteBalance + 1, baseBalance, customData);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        market.flash(_BORROWER, quoteBalance, baseBalance + 1, customData);
    }

    function testFlashSuccessOverPayedFee() public {
        uint256 quoteAmount = 100 * 1e6;
        uint256 baseAmount = 100 * 1e18;

        uint256 beforeThisQuote = quoteToken.balanceOf(address(this));
        uint256 beforeThisBase = baseToken.balanceOf(address(this));
        uint256 beforeMarketQuote = quoteToken.balanceOf(address(market));
        uint256 beforeMarketBase = baseToken.balanceOf(address(market));

        uint256 expectedQuoteFee = quoteAmount;
        uint256 expectedBaseFee = baseAmount;
        customData = abi.encode(bytes32("customFee"), abi.encode(expectedQuoteFee, expectedBaseFee));

        vm.expectEmit(true, true, true, true);
        emit Flash(address(this), _BORROWER, quoteAmount, baseAmount, expectedQuoteFee, expectedBaseFee);
        market.flash(_BORROWER, quoteAmount, baseAmount, customData);

        uint256 thisQuoteDiff = beforeThisQuote - quoteToken.balanceOf(address(this));
        uint256 thisBaseDiff = beforeThisBase - baseToken.balanceOf(address(this));
        uint256 marketQuoteDiff = quoteToken.balanceOf(address(market)) - beforeMarketQuote;
        uint256 marketBaseDiff = baseToken.balanceOf(address(market)) - beforeMarketBase;

        assertEq(thisQuoteDiff, quoteAmount + expectedQuoteFee, "THIS_QUOTE_AMOUNT");
        assertEq(thisBaseDiff, baseAmount + expectedBaseFee, "THIS_BASE_AMOUNT");
        assertEq(quoteToken.balanceOf(_BORROWER), quoteAmount, "BORROWER_QUOTE_AMOUNT");
        assertEq(baseToken.balanceOf(_BORROWER), baseAmount, "BORROWER_BASE_AMOUNT");
        assertEq(marketQuoteDiff, expectedQuoteFee, "MARKET_QUOTE_AMOUNT");
        assertEq(marketBaseDiff, expectedBaseFee, "MARKET_BASE_AMOUNT");
        (uint128 quoteFeeBalance, uint128 baseFeeBalance) = market.getFeeBalance();
        assertEq(quoteFeeBalance, expectedQuoteFee, "PROTOCOL_FEE_QUOTE_AMOUNT");
        assertEq(baseFeeBalance, expectedBaseFee, "PROTOCOL_FEE_BASE_AMOUNT");
    }

    function testFlashInsufficientFee() public {
        uint256 quoteAmount = 100 * 1e6;
        uint256 baseAmount = 100 * 1e18;

        uint256 expectedQuoteFee = (quoteAmount * Constants.TAKE_FEE) / Constants.FEE_PRECISION;
        uint256 expectedBaseFee = (baseAmount * Constants.TAKE_FEE) / Constants.FEE_PRECISION;
        customData = abi.encode(bytes32("customFee"), abi.encode(expectedQuoteFee - 1, expectedBaseFee));

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INSUFFICIENT_BALANCE));
        market.flash(_BORROWER, quoteAmount, baseAmount, customData);

        customData = abi.encode(bytes32("customFee"), abi.encode(expectedQuoteFee, expectedBaseFee - 1));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INSUFFICIENT_BALANCE));
        market.flash(_BORROWER, quoteAmount, baseAmount, customData);
    }
}
