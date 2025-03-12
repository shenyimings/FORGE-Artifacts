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
import "../utils/MockingFactoryTest.sol";
import "./Constants.sol";

contract OrderBookClaimUnitTest is Test, CloberMarketSwapCallbackReceiver, MockingFactoryTest {
    using OrderKeyUtils for OrderKey;
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

    struct Vars {
        uint256 orderIndex;
        uint256 expectedClaimAmount;
        uint256 expectedMakerFee;
        uint256 expectedTakerFee;
        uint256 expectedTakeAmount;
        uint256 beforeNFTBalance;
        uint256 beforeQuoteBalance;
        uint256 beforeBaseBalance;
        uint256 beforeQuoteFeeBalance;
        uint256 beforeBaseFeeBalance;
        uint256 beforeHostQuoteBalance;
        uint256 beforeHostBaseBalance;
        uint256 afterQuoteFeeBalance;
        uint256 afterBaseFeeBalance;
        uint256 expectedDaoFeeQuote;
        uint256 expectedDaoFeeBase;
        uint256 claimableAmount;
        uint256 feeAmount;
        uint256 rebateAmount;
        uint64 claimableRawAmount;
    }

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
        receivedEthers += msg.value;
    }

    function _collectFees() internal {
        orderBook.collectFees(address(quoteToken), address(this));
        orderBook.collectFees(address(quoteToken), daoTreasury);
        orderBook.collectFees(address(baseToken), address(this));
        orderBook.collectFees(address(baseToken), daoTreasury);
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

    function _createPostOnlyOrder(bool isBid, uint64 rawAmount) private returns (uint256) {
        if (isBid) {
            return
                orderBook.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}({
                    user: Constants.MAKER,
                    priceIndex: Constants.PRICE_INDEX,
                    rawAmount: rawAmount,
                    baseAmount: 0,
                    options: 3,
                    data: new bytes(0)
                });
        } else {
            return
                orderBook.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}({
                    user: Constants.MAKER,
                    priceIndex: Constants.PRICE_INDEX,
                    rawAmount: 0,
                    baseAmount: orderBook.rawToBase(rawAmount, Constants.PRICE_INDEX, true),
                    options: 2,
                    data: new bytes(0)
                });
        }
    }

    function _createTakeOrder(bool isTakingBid, uint64 rawAmount) private {
        if (isTakingBid) {
            orderBook.limitOrder({
                user: Constants.TAKER,
                priceIndex: Constants.PRICE_INDEX,
                rawAmount: 0,
                baseAmount: orderBook.rawToBase(rawAmount, Constants.PRICE_INDEX, true),
                options: 0,
                data: new bytes(0)
            });
        } else {
            orderBook.limitOrder({
                user: Constants.TAKER,
                priceIndex: Constants.PRICE_INDEX,
                rawAmount: rawAmount,
                baseAmount: 0,
                options: 1,
                data: new bytes(0)
            });
        }
    }

    function _createSettledOrder(bool isBid, uint64 rawAmount) private returns (uint256) {
        uint256 orderIndex = _createPostOnlyOrder(isBid, rawAmount);
        _createTakeOrder(isBid, rawAmount);
        return orderIndex;
    }

    function _toArray(OrderKey memory orderKey) private pure returns (OrderKey[] memory) {
        OrderKey[] memory ids = new OrderKey[](1);
        ids[0] = orderKey;
        return ids;
    }

    function testClaimBidOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        Vars memory vars;

        vars.orderIndex = _createSettledOrder(Constants.BID, Constants.RAW_AMOUNT);

        vars.expectedClaimAmount = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false);
        vars.expectedMakerFee = Math.divide(
            vars.expectedClaimAmount * Constants.MAKE_FEE,
            Constants.FEE_PRECISION,
            true
        );
        // calculate taker fee that protocol gained
        vars.expectedTakerFee =
            (orderBook.rawToQuote(Constants.RAW_AMOUNT) * Constants.TAKE_FEE) /
            Constants.FEE_PRECISION;

        vars.beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        vars.beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        (vars.beforeQuoteFeeBalance, vars.beforeBaseFeeBalance) = orderBook.getFeeBalance();
        vars.beforeHostQuoteBalance = quoteToken.balanceOf(address(this));
        vars.beforeHostBaseBalance = baseToken.balanceOf(address(this));
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, Constants.RAW_AMOUNT, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, vars.expectedClaimAmount - vars.expectedMakerFee, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, vars.expectedMakerFee, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.BID, Constants.PRICE_INDEX, 0).encode()))
        );
        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            address(this),
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            Constants.CLAIM_BOUNTY * 1 gwei,
            vars.orderIndex,
            Constants.PRICE_INDEX,
            Constants.BID
        );
        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex}))
        );
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, 0, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, 0, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, 0, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        (vars.afterQuoteFeeBalance, vars.afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(
            baseToken.balanceOf(Constants.MAKER) - vars.beforeBaseBalance,
            vars.expectedClaimAmount - vars.expectedMakerFee,
            "ERROR_BASE_BALANCE"
        );
        assertEq(
            vars.afterQuoteFeeBalance - vars.beforeQuoteFeeBalance,
            vars.expectedTakerFee,
            "ERROR_PROTOCOL_FEE_QUOTE_BALANCE"
        );
        assertEq(
            vars.afterBaseFeeBalance - vars.beforeBaseFeeBalance,
            vars.expectedMakerFee,
            "ERROR_PROTOCOL_FEE_BASE_BALANCE"
        );
        assertEq(receivedEthers, Constants.CLAIM_BOUNTY * 1 gwei, "ERROR_CLAIM_BOUNTY_BALANCE");

        _collectFees();
        vars.expectedDaoFeeQuote = Math.divide(
            vars.expectedTakerFee * Constants.DAO_FEE,
            Constants.FEE_PRECISION,
            true
        );
        vars.expectedDaoFeeBase = Math.divide(vars.expectedMakerFee * Constants.DAO_FEE, Constants.FEE_PRECISION, true);
        assertEq(quoteToken.balanceOf(daoTreasury), vars.expectedDaoFeeQuote, "ERROR_DAO_QUOTE_BALANCE");
        assertEq(baseToken.balanceOf(daoTreasury), vars.expectedDaoFeeBase, "ERROR_DAO_BASE_BALANCE");
        assertEq(
            quoteToken.balanceOf(address(this)) - vars.beforeHostQuoteBalance,
            vars.expectedTakerFee - vars.expectedDaoFeeQuote,
            "ERROR_HOST_QUOTE_BALANCE"
        );
        assertEq(
            baseToken.balanceOf(address(this)) - vars.beforeHostBaseBalance,
            vars.expectedMakerFee - vars.expectedDaoFeeBase,
            "ERROR_HOST_BASE_BALANCE"
        );
        assertEq(vars.beforeNFTBalance - orderToken.balanceOf(Constants.MAKER), 1, "ERROR_NFT_BALANCE");
    }

    function testClaimAskOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        Vars memory vars;

        vars.orderIndex = _createSettledOrder(Constants.ASK, Constants.RAW_AMOUNT);

        vars.expectedClaimAmount = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        vars.expectedMakerFee = Math.divide(
            vars.expectedClaimAmount * Constants.MAKE_FEE,
            Constants.FEE_PRECISION,
            true
        );
        // calculate taker fee that protocol gained
        vars.expectedTakerFee =
            (orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false) * Constants.TAKE_FEE) /
            Constants.FEE_PRECISION;

        vars.beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        vars.beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        (vars.beforeQuoteFeeBalance, vars.beforeBaseFeeBalance) = orderBook.getFeeBalance();
        vars.beforeHostQuoteBalance = quoteToken.balanceOf(address(this));
        vars.beforeHostBaseBalance = baseToken.balanceOf(address(this));
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, Constants.RAW_AMOUNT, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, vars.expectedClaimAmount - vars.expectedMakerFee, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, vars.expectedMakerFee, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(
                CloberOrderNFT.onBurn,
                (OrderKey(Constants.ASK, Constants.PRICE_INDEX, vars.orderIndex).encode())
            )
        );
        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            address(this),
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            Constants.CLAIM_BOUNTY * 1 gwei,
            vars.orderIndex,
            Constants.PRICE_INDEX,
            Constants.ASK
        );
        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex}))
        );
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, 0, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, 0, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, 0, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        (vars.afterQuoteFeeBalance, vars.afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(
            quoteToken.balanceOf(Constants.MAKER) - vars.beforeQuoteBalance,
            vars.expectedClaimAmount - vars.expectedMakerFee,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(
            vars.afterQuoteFeeBalance - vars.beforeQuoteFeeBalance,
            vars.expectedMakerFee,
            "PROTOCOL_FEE_QUOTE_BALANCE"
        );
        assertEq(
            vars.afterBaseFeeBalance - vars.beforeBaseFeeBalance,
            vars.expectedTakerFee,
            "PROTOCOL_FEE_BASE_BALANCE"
        );
        assertEq(receivedEthers, Constants.CLAIM_BOUNTY * 1 gwei, "CLAIM_BOUNTY_BALANCE");

        _collectFees();
        vars.expectedDaoFeeQuote = Math.divide(
            vars.expectedMakerFee * Constants.DAO_FEE,
            Constants.FEE_PRECISION,
            true
        );
        vars.expectedDaoFeeBase = Math.divide(vars.expectedTakerFee * Constants.DAO_FEE, Constants.FEE_PRECISION, true);
        assertEq(quoteToken.balanceOf(daoTreasury), vars.expectedDaoFeeQuote, "ERROR_DAO_QUOTE_BALANCE");
        assertEq(baseToken.balanceOf(daoTreasury), vars.expectedDaoFeeBase, "ERROR_DAO_BASE_BALANCE");
        assertEq(
            quoteToken.balanceOf(address(this)) - vars.beforeHostQuoteBalance,
            vars.expectedMakerFee - vars.expectedDaoFeeQuote,
            "ERROR_HOST_QUOTE_BALANCE"
        );
        assertEq(
            baseToken.balanceOf(address(this)) - vars.beforeHostBaseBalance,
            vars.expectedTakerFee - vars.expectedDaoFeeBase,
            "ERROR_HOST_BASE_BALANCE"
        );
        assertEq(vars.beforeNFTBalance - orderToken.balanceOf(Constants.MAKER), 1, "ERROR_NFT_BALANCE");
    }

    function testClaimPartiallyFilledBidOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        Vars memory vars;

        vars.orderIndex = _createPostOnlyOrder(Constants.BID, Constants.RAW_AMOUNT * 2);
        _createTakeOrder(Constants.BID, Constants.RAW_AMOUNT);

        vars.expectedClaimAmount = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false);
        vars.expectedMakerFee = Math.divide(
            vars.expectedClaimAmount * Constants.MAKE_FEE,
            Constants.FEE_PRECISION,
            true
        );
        // calculate taker fee that protocol gained
        vars.expectedTakerFee =
            (orderBook.rawToQuote(Constants.RAW_AMOUNT) * Constants.TAKE_FEE) /
            Constants.FEE_PRECISION;

        vars.beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        (vars.beforeQuoteFeeBalance, vars.beforeBaseFeeBalance) = orderBook.getFeeBalance();
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, Constants.RAW_AMOUNT, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, vars.expectedClaimAmount - vars.expectedMakerFee, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, vars.expectedMakerFee, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            address(this),
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            0,
            vars.orderIndex,
            Constants.PRICE_INDEX,
            Constants.BID
        );
        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex}))
        );
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, 0, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, 0, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, 0, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        (vars.afterQuoteFeeBalance, vars.afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(
            baseToken.balanceOf(Constants.MAKER) - vars.beforeBaseBalance,
            vars.expectedClaimAmount - vars.expectedMakerFee,
            "ERROR_BASE_BALANCE"
        );
        assertEq(
            vars.afterQuoteFeeBalance - vars.beforeQuoteFeeBalance,
            vars.expectedTakerFee,
            "ERROR_PROTOCOL_FEE_QUOTE_BALANCE"
        );
        assertEq(
            vars.afterBaseFeeBalance - vars.beforeBaseFeeBalance,
            vars.expectedMakerFee,
            "ERROR_PROTOCOL_FEE_BASE_BALANCE"
        );
        assertEq(receivedEthers, 0, "ERROR_CLAIM_BOUNTY_BALANCE");
    }

    function testClaimPartiallyFilledAskOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        Vars memory vars;

        vars.orderIndex = _createPostOnlyOrder(Constants.ASK, Constants.RAW_AMOUNT * 2);
        _createTakeOrder(Constants.ASK, Constants.RAW_AMOUNT);

        vars.expectedClaimAmount = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        vars.expectedMakerFee = Math.divide(
            vars.expectedClaimAmount * Constants.MAKE_FEE,
            Constants.FEE_PRECISION,
            true
        );
        // calculate taker fee that protocol gained
        vars.expectedTakerFee =
            (orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false) * Constants.TAKE_FEE) /
            Constants.FEE_PRECISION;

        vars.beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        (vars.beforeQuoteFeeBalance, vars.beforeBaseFeeBalance) = orderBook.getFeeBalance();
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, Constants.RAW_AMOUNT, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, vars.expectedClaimAmount - vars.expectedMakerFee, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, vars.expectedMakerFee, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            address(this),
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            0,
            vars.orderIndex,
            Constants.PRICE_INDEX,
            Constants.ASK
        );
        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex}))
        );
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, 0, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, 0, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, 0, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        (vars.afterQuoteFeeBalance, vars.afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(
            quoteToken.balanceOf(Constants.MAKER) - vars.beforeQuoteBalance,
            vars.expectedClaimAmount - vars.expectedMakerFee,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(
            vars.afterQuoteFeeBalance - vars.beforeQuoteFeeBalance,
            vars.expectedMakerFee,
            "PROTOCOL_FEE_QUOTE_BALANCE"
        );
        assertEq(
            vars.afterBaseFeeBalance - vars.beforeBaseFeeBalance,
            vars.expectedTakerFee,
            "PROTOCOL_FEE_BASE_BALANCE"
        );
        assertEq(receivedEthers, 0, "CLAIM_BOUNTY_BALANCE");
    }

    function testClaimReplacedBidOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        for (uint256 i = 0; i < Constants.MAX_ORDER; i++) {
            _createPostOnlyOrder(Constants.BID, Constants.RAW_AMOUNT);
        }
        _createTakeOrder(Constants.BID, Constants.RAW_AMOUNT);

        uint256 expectedClaimAmount = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false);
        uint256 expectedMakerFee = Math.divide(expectedClaimAmount * Constants.MAKE_FEE, Constants.FEE_PRECISION, true);
        // calculate taker fee that protocol gained
        uint256 expectedTakerFee = (orderBook.rawToQuote(Constants.RAW_AMOUNT) * Constants.TAKE_FEE) /
            Constants.FEE_PRECISION;

        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        uint256 beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        (uint256 beforeQuoteFeeBalance, uint256 beforeBaseFeeBalance) = orderBook.getFeeBalance();
        uint256 beforeMakerBalance = Constants.MAKER.balance;

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.RAW_AMOUNT);
        assertEq(orderIndex, Constants.MAX_ORDER, "ERROR_ORDER_INDEX");

        (uint256 afterQuoteFeeBalance, uint256 afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(baseToken.balanceOf(Constants.MAKER), beforeBaseBalance, "ERROR_BASE_BALANCE_0");
        assertEq(afterQuoteFeeBalance, beforeQuoteFeeBalance, "ERROR_PROTOCOL_FEE_QUOTE_BALANCE_0");
        assertEq(afterBaseFeeBalance, beforeBaseFeeBalance, "ERROR_PROTOCOL_FEE_BASE_BALANCE_0");
        assertEq(Constants.MAKER.balance, beforeMakerBalance, "ERROR_CLAIM_BOUNTY_BALANCE_0");
        assertEq(beforeNFTBalance + 1, orderToken.balanceOf(Constants.MAKER), "ERROR_NFT_BALANCE_0");

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.BID, Constants.PRICE_INDEX, 0).encode()))
        );
        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            Constants.MAKER,
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            Constants.CLAIM_BOUNTY * 1 gwei,
            0,
            Constants.PRICE_INDEX,
            Constants.BID
        );
        orderBook.claim(
            Constants.MAKER,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: 0}))
        );

        (afterQuoteFeeBalance, afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(
            baseToken.balanceOf(Constants.MAKER) - beforeBaseBalance,
            expectedClaimAmount - expectedMakerFee,
            "ERROR_BASE_BALANCE"
        );
        assertEq(afterQuoteFeeBalance - beforeQuoteFeeBalance, expectedTakerFee, "ERROR_PROTOCOL_FEE_QUOTE_BALANCE");
        assertEq(afterBaseFeeBalance - beforeBaseFeeBalance, expectedMakerFee, "ERROR_PROTOCOL_FEE_BASE_BALANCE");
        assertEq(
            Constants.MAKER.balance - beforeMakerBalance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY_BALANCE"
        );
        assertEq(beforeNFTBalance, orderToken.balanceOf(Constants.MAKER), "ERROR_NFT_BALANCE");
    }

    function testClaimReplacedAskOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        for (uint256 i = 0; i < Constants.MAX_ORDER; i++) {
            _createPostOnlyOrder(Constants.ASK, Constants.RAW_AMOUNT);
        }
        _createTakeOrder(Constants.ASK, Constants.RAW_AMOUNT);

        uint256 expectedClaimAmount = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        uint256 expectedMakerFee = Math.divide(expectedClaimAmount * Constants.MAKE_FEE, Constants.FEE_PRECISION, true);
        // calculate taker fee that protocol gained
        uint256 expectedTakerFee = (orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false) *
            Constants.TAKE_FEE) / Constants.FEE_PRECISION;

        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        uint256 beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        (uint256 beforeQuoteFeeBalance, uint256 beforeBaseFeeBalance) = orderBook.getFeeBalance();
        uint256 beforeMakerBalance = Constants.MAKER.balance;

        uint256 orderIndex = _createPostOnlyOrder(Constants.ASK, Constants.RAW_AMOUNT);
        assertEq(orderIndex, Constants.MAX_ORDER, "ERROR_ORDER_INDEX");

        (uint256 afterQuoteFeeBalance, uint256 afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(quoteToken.balanceOf(Constants.MAKER), beforeQuoteBalance, "ERROR_QUOTE_BALANCE_0");
        assertEq(afterQuoteFeeBalance, beforeQuoteFeeBalance, "PROTOCOL_FEE_QUOTE_BALANCE_0");
        assertEq(afterBaseFeeBalance, beforeBaseFeeBalance, "PROTOCOL_FEE_BASE_BALANCE_0");
        assertEq(Constants.MAKER.balance, beforeMakerBalance, "CLAIM_BOUNTY_BALANCE_0");
        assertEq(beforeNFTBalance + 1, orderToken.balanceOf(Constants.MAKER), "ERROR_NFT_BALANCE_0");

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.ASK, Constants.PRICE_INDEX, 0).encode()))
        );
        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            Constants.MAKER,
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            Constants.CLAIM_BOUNTY * 1 gwei,
            0,
            Constants.PRICE_INDEX,
            Constants.ASK
        );
        orderBook.claim(
            Constants.MAKER,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: 0}))
        );

        (afterQuoteFeeBalance, afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(
            quoteToken.balanceOf(Constants.MAKER) - beforeQuoteBalance,
            expectedClaimAmount - expectedMakerFee,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(afterQuoteFeeBalance - beforeQuoteFeeBalance, expectedMakerFee, "PROTOCOL_FEE_QUOTE_BALANCE");
        assertEq(afterBaseFeeBalance - beforeBaseFeeBalance, expectedTakerFee, "PROTOCOL_FEE_BASE_BALANCE");
        assertEq(Constants.MAKER.balance - beforeMakerBalance, Constants.CLAIM_BOUNTY * 1 gwei, "CLAIM_BOUNTY_BALANCE");
        assertEq(beforeNFTBalance, orderToken.balanceOf(Constants.MAKER), "ERROR_NFT_BALANCE");
    }

    function testClaimBidOrderWithNegativeMakeFee() public {
        _createOrderBook(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        Vars memory vars;

        vars.orderIndex = _createSettledOrder(Constants.BID, Constants.RAW_AMOUNT);

        vars.expectedClaimAmount = orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false);
        vars.expectedTakeAmount = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        vars.expectedMakerFee = (vars.expectedTakeAmount * Constants.MAKE_FEE) / Constants.FEE_PRECISION;
        // calculate taker fee that protocol gained
        vars.expectedTakerFee = (vars.expectedTakeAmount * Constants.TAKE_FEE) / Constants.FEE_PRECISION;

        vars.beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        vars.beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        vars.beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        (vars.beforeQuoteFeeBalance, ) = orderBook.getFeeBalance();
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, Constants.RAW_AMOUNT, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, vars.expectedClaimAmount, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, 0, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, vars.expectedMakerFee, "ERROR_REBATE_AMOUNT");

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(
                CloberOrderNFT.onBurn,
                (OrderKey(Constants.BID, Constants.PRICE_INDEX, vars.orderIndex).encode())
            )
        );
        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            address(this),
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            Constants.CLAIM_BOUNTY * 1 gwei,
            vars.orderIndex,
            Constants.PRICE_INDEX,
            Constants.BID
        );
        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex}))
        );
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, 0, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, 0, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, 0, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        (vars.afterQuoteFeeBalance, ) = orderBook.getFeeBalance();
        assertEq(
            baseToken.balanceOf(Constants.MAKER) - vars.beforeBaseBalance,
            vars.expectedClaimAmount,
            "ERROR_BASE_BALANCE"
        );
        assertEq(
            quoteToken.balanceOf(Constants.MAKER) - vars.beforeQuoteBalance,
            vars.expectedMakerFee,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(
            vars.afterQuoteFeeBalance - vars.beforeQuoteFeeBalance,
            vars.expectedTakerFee - vars.expectedMakerFee,
            "ERROR_PROTOCOL_FEE_QUOTE_BALANCE"
        );
        assertEq(receivedEthers, Constants.CLAIM_BOUNTY * 1 gwei, "ERROR_CLAIM_BOUNTY_BALANCE");
        assertEq(vars.beforeNFTBalance - orderToken.balanceOf(Constants.MAKER), 1, "ERROR_NFT_BALANCE");
    }

    function testClaimAskOrderWithNegativeMakeFee() public {
        _createOrderBook(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);
        Vars memory vars;

        vars.orderIndex = _createSettledOrder(Constants.ASK, Constants.RAW_AMOUNT);

        vars.expectedClaimAmount = orderBook.rawToQuote(Constants.RAW_AMOUNT);
        vars.expectedMakerFee =
            (orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true) * Constants.MAKE_FEE) /
            Constants.FEE_PRECISION;
        // calculate taker fee that protocol gained, rounding down here
        vars.expectedTakerFee =
            (orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, false) * Constants.TAKE_FEE) /
            Constants.FEE_PRECISION;

        vars.beforeNFTBalance = orderToken.balanceOf(Constants.MAKER);
        vars.beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        vars.beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        (, vars.beforeBaseFeeBalance) = orderBook.getFeeBalance();
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, Constants.RAW_AMOUNT, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, vars.expectedClaimAmount, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, 0, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, vars.expectedMakerFee, "ERROR_REBATE_AMOUNT");

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(
                CloberOrderNFT.onBurn,
                (OrderKey(Constants.ASK, Constants.PRICE_INDEX, vars.orderIndex).encode())
            )
        );
        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            address(this),
            Constants.MAKER,
            Constants.RAW_AMOUNT,
            Constants.CLAIM_BOUNTY * 1 gwei,
            vars.orderIndex,
            Constants.PRICE_INDEX,
            Constants.ASK
        );
        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex}))
        );
        (vars.claimableRawAmount, vars.claimableAmount, vars.feeAmount, vars.rebateAmount) = orderBook.getClaimable(
            OrderKey({isBid: Constants.ASK, priceIndex: Constants.PRICE_INDEX, orderIndex: vars.orderIndex})
        );
        assertEq(vars.claimableRawAmount, 0, "ERROR_CLAIMABLE_RAW_AMOUNT");
        assertEq(vars.claimableAmount, 0, "ERROR_CLAIMABLE_AMOUNT");
        assertEq(vars.feeAmount, 0, "ERROR_FEE_AMOUNT");
        assertEq(vars.rebateAmount, 0, "ERROR_REBATE_AMOUNT");

        (, vars.afterBaseFeeBalance) = orderBook.getFeeBalance();
        assertEq(
            quoteToken.balanceOf(Constants.MAKER) - vars.beforeQuoteBalance,
            vars.expectedClaimAmount,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(
            baseToken.balanceOf(Constants.MAKER) - vars.beforeBaseBalance,
            vars.expectedMakerFee,
            "ERROR_BASE_BALANCE"
        );
        assertEq(
            vars.afterBaseFeeBalance - vars.beforeBaseFeeBalance,
            vars.expectedTakerFee - vars.expectedMakerFee,
            "ERROR_PROTOCOL_FEE_BASE_BALANCE"
        );
        assertEq(receivedEthers, Constants.CLAIM_BOUNTY * 1 gwei, "ERROR_CLAIM_BOUNTY_BALANCE");
        assertEq(vars.beforeNFTBalance - orderToken.balanceOf(Constants.MAKER), 1, "ERROR_NFT_BALANCE");
    }

    function testClaimEmptyOrder() public {
        _createOrderBook(0, 0);

        uint256 beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        uint256 beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: 100}))
        );
        assertEq(quoteToken.balanceOf(Constants.MAKER), beforeQuoteBalance, "QUOTE_BALANCE");
        assertEq(baseToken.balanceOf(Constants.MAKER), beforeBaseBalance, "BASE_BALANCE");
    }

    function testClaimNotFilledOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.RAW_AMOUNT);

        uint256 beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        uint256 beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );
        assertEq(quoteToken.balanceOf(Constants.MAKER), beforeQuoteBalance, "QUOTE_BALANCE");
        assertEq(baseToken.balanceOf(Constants.MAKER), beforeBaseBalance, "BASE_BALANCE");
    }

    function testClaimAlreadyClaimedOrder() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.RAW_AMOUNT);

        vm.prank(Constants.MAKER);
        orderBook.limitOrder({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true),
            options: 0,
            data: new bytes(0)
        });

        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );

        uint256 beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        uint256 beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        orderBook.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );
        assertEq(quoteToken.balanceOf(Constants.MAKER), beforeQuoteBalance, "QUOTE_BALANCE");
        assertEq(baseToken.balanceOf(Constants.MAKER), beforeBaseBalance, "BASE_BALANCE");
    }

    function testClaimWhenOrderIndexIsOutOfRange() public {
        _createOrderBook(int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint256 orderIndex = _createPostOnlyOrder(Constants.BID, Constants.RAW_AMOUNT);
        vm.prank(Constants.MAKER);
        orderBook.cancel(
            Constants.MAKER,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: Constants.PRICE_INDEX, orderIndex: orderIndex}))
        );

        // Fill all the orders
        for (uint256 i = 0; i < Constants.MAX_ORDER - 1; i++) {
            _createPostOnlyOrder(Constants.BID, Constants.RAW_AMOUNT);
        }
        orderIndex = _createPostOnlyOrder(Constants.BID, Constants.RAW_AMOUNT);

        // Take the last order
        uint256 counterOrderIndex = orderBook.limitOrder({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(
                Constants.RAW_AMOUNT * (Constants.MAX_ORDER + 1),
                Constants.PRICE_INDEX,
                true
            ),
            options: 0,
            data: new bytes(0)
        });
        assertLt(counterOrderIndex, type(uint256).max, "NOT_TAKEN");

        uint256 beforeQuoteBalance = quoteToken.balanceOf(Constants.MAKER);
        uint256 beforeBaseBalance = baseToken.balanceOf(Constants.MAKER);
        orderBook.claim(
            address(this),
            _toArray(
                OrderKey({
                    isBid: Constants.BID,
                    priceIndex: Constants.PRICE_INDEX,
                    orderIndex: orderIndex - Constants.MAX_ORDER
                })
            )
        );
        assertEq(quoteToken.balanceOf(Constants.MAKER), beforeQuoteBalance, "QUOTE_BALANCE_LESS");
        assertEq(baseToken.balanceOf(Constants.MAKER), beforeBaseBalance, "BASE_BALANCE_LESS");
        orderBook.claim(
            address(this),
            _toArray(
                OrderKey({
                    isBid: Constants.BID,
                    priceIndex: Constants.PRICE_INDEX,
                    orderIndex: orderIndex + Constants.MAX_ORDER
                })
            )
        );
        assertEq(quoteToken.balanceOf(Constants.MAKER), beforeQuoteBalance, "QUOTE_BALANCE_GREATER");
        assertEq(baseToken.balanceOf(Constants.MAKER), beforeBaseBalance, "BASE_BALANCE_GREATER");
    }

    function testRefundClaimBountyAllWhenTake() public {
        _createOrderBook(0, 0);

        _createPostOnlyOrder(Constants.BID, Constants.RAW_AMOUNT);

        vm.deal(Constants.MAKER, 1300000000);
        assertEq(Constants.MAKER.balance, 1300000000);
        vm.prank(Constants.MAKER);
        orderBook.limitOrder{value: 1300000000}({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: 0,
            baseAmount: orderBook.rawToBase(Constants.RAW_AMOUNT, Constants.PRICE_INDEX, true),
            options: 0,
            data: new bytes(0)
        });
        assertEq(Constants.MAKER.balance, 1300000000);
    }

    function testRefundClaimBountyWhenValueIsWEI() public {
        _createOrderBook(0, 0);

        vm.deal(address(this), 1300000000);
        uint256 beforeOrderBookETHBalance = address(orderBook).balance;
        orderBook.limitOrder{value: 1300000000}({
            user: Constants.MAKER,
            priceIndex: Constants.PRICE_INDEX,
            rawAmount: Constants.RAW_AMOUNT,
            baseAmount: 0,
            options: 3,
            data: new bytes(0)
        });
        assertEq(address(this).balance, 300000000);
        assertEq(address(orderBook).balance - beforeOrderBookETHBalance, 1 gwei);
    }
}
