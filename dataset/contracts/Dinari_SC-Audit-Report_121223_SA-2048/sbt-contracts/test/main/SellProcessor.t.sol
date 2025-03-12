// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {MockToken} from "../utils/mocks/MockToken.sol";
import "../utils/mocks/MockdShareFactory.sol";
import "../utils/SigUtils.sol";
import "../../src/orders/SellProcessor.sol";
import "../../src/orders/IOrderProcessor.sol";
import {TokenLockCheck, ITokenLockCheck} from "../../src/TokenLockCheck.sol";
import {FeeLib} from "../../src/common/FeeLib.sol";

contract SellProcessorTest is Test {
    event OrderRequested(address indexed recipient, uint256 indexed index, IOrderProcessor.Order order);
    event OrderFill(
        address indexed recipient, uint256 indexed index, uint256 fillAmount, uint256 receivedAmount, uint256 feesPaid
    );
    event OrderFulfilled(address indexed recipient, uint256 indexed index);
    event CancelRequested(address indexed recipient, uint256 indexed index);
    event OrderCancelled(address indexed recipient, uint256 indexed index, string reason);
    event MaxOrderDecimalsSet(address indexed assetToken, uint256 decimals);

    MockdShareFactory tokenFactory;
    dShare token;
    TokenLockCheck tokenLockCheck;
    SellProcessor issuer;
    MockToken paymentToken;

    uint256 userPrivateKey;
    address user;

    address constant operator = address(3);
    address constant treasury = address(4);
    uint256 flatFee;
    uint24 percentageFeeRate;

    IOrderProcessor.Order dummyOrder;

    function setUp() public {
        userPrivateKey = 0x01;
        user = vm.addr(userPrivateKey);

        tokenFactory = new MockdShareFactory();
        token = tokenFactory.deploy("Dinari Token", "dTKN");
        paymentToken = new MockToken("Money", "$");

        tokenLockCheck = new TokenLockCheck(address(paymentToken), address(paymentToken));

        issuer = new SellProcessor(address(this), treasury, 1 ether, 5_000, tokenLockCheck);

        token.grantRole(token.MINTER_ROLE(), address(this));
        token.grantRole(token.BURNER_ROLE(), address(issuer));

        issuer.grantRole(issuer.PAYMENTTOKEN_ROLE(), address(paymentToken));
        issuer.grantRole(issuer.ASSETTOKEN_ROLE(), address(token));
        issuer.grantRole(issuer.OPERATOR_ROLE(), operator);

        (flatFee, percentageFeeRate) = issuer.getFeeRatesForOrder(user, true, address(paymentToken));
        dummyOrder = IOrderProcessor.Order({
            recipient: user,
            assetToken: address(token),
            paymentToken: address(paymentToken),
            sell: true,
            orderType: IOrderProcessor.OrderType.MARKET,
            assetTokenQuantity: 100 ether,
            paymentTokenQuantity: 0,
            price: 0,
            tif: IOrderProcessor.TIF.GTC
        });
    }

    function testRequestOrder(uint256 quantityIn) public {
        IOrderProcessor.Order memory order = dummyOrder;
        order.assetTokenQuantity = quantityIn;

        token.mint(user, quantityIn);
        vm.prank(user);
        token.approve(address(issuer), quantityIn);

        bytes32 id = issuer.getOrderId(order.recipient, 0);

        if (quantityIn == 0) {
            vm.expectRevert(OrderProcessor.ZeroValue.selector);
            vm.prank(user);
            issuer.requestOrder(order);
        } else {
            // balances before
            uint256 userBalanceBefore = token.balanceOf(user);
            uint256 issuerBalanceBefore = token.balanceOf(address(issuer));
            vm.expectEmit(true, true, true, true);
            emit OrderRequested(order.recipient, 0, order);
            vm.prank(user);
            issuer.requestOrder(order);
            assertEq(uint8(issuer.getOrderStatus(id)), uint8(IOrderProcessor.OrderStatus.ACTIVE));
            assertEq(issuer.getUnfilledAmount(id), quantityIn);
            assertEq(issuer.numOpenOrders(), 1);
            assertEq(token.balanceOf(address(issuer)), quantityIn);
            // balances after
            assertEq(token.balanceOf(user), userBalanceBefore - quantityIn);
            assertEq(token.balanceOf(address(issuer)), issuerBalanceBefore + quantityIn);
            assertEq(issuer.escrowedBalanceOf(order.assetToken, user), quantityIn);
        }
    }

    function testInvalidPrecisionRequestOrder() public {
        uint256 orderAmount = 100000255;
        OrderProcessor.Order memory order = dummyOrder;

        vm.expectEmit(true, true, true, true);
        emit MaxOrderDecimalsSet(order.assetToken, 2);
        issuer.setMaxOrderDecimals(order.assetToken, 2);
        order.assetTokenQuantity = orderAmount;

        token.mint(user, order.assetTokenQuantity);
        vm.prank(user);
        token.approve(address(issuer), order.assetTokenQuantity);

        vm.expectRevert(OrderProcessor.InvalidPrecision.selector);
        vm.prank(user);
        issuer.requestOrder(order);

        // update OrderAmount
        order.assetTokenQuantity = 100000;

        token.approve(address(issuer), order.assetTokenQuantity);

        vm.prank(user);
        issuer.requestOrder(order);
    }

    function testFillOrder(uint256 orderAmount, uint256 fillAmount, uint256 receivedAmount) public {
        vm.assume(orderAmount > 0);

        IOrderProcessor.Order memory order = dummyOrder;
        order.assetTokenQuantity = orderAmount;

        uint256 feesEarned = 0;
        if (receivedAmount > 0) {
            if (receivedAmount <= flatFee) {
                feesEarned = receivedAmount;
            } else {
                feesEarned = flatFee + PrbMath.mulDiv18(receivedAmount - flatFee, percentageFeeRate);
            }
        }

        token.mint(user, orderAmount);
        vm.prank(user);
        token.approve(address(issuer), orderAmount);

        vm.prank(user);
        uint256 index = issuer.requestOrder(order);

        uint256 escrowAmount = issuer.escrowedBalanceOf(order.assetToken, user);
        assertEq(escrowAmount, orderAmount);

        paymentToken.mint(operator, receivedAmount);
        vm.prank(operator);
        paymentToken.approve(address(issuer), receivedAmount);

        bytes32 id = issuer.getOrderId(order.recipient, index);

        if (fillAmount == 0) {
            vm.expectRevert(OrderProcessor.ZeroValue.selector);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
        } else if (fillAmount > orderAmount) {
            vm.expectRevert(OrderProcessor.AmountTooLarge.selector);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
        } else {
            // balances before
            uint256 userPaymentBefore = paymentToken.balanceOf(user);
            uint256 issuerAssetBefore = token.balanceOf(address(issuer));
            uint256 operatorPaymentBefore = paymentToken.balanceOf(operator);
            vm.expectEmit(true, true, true, false);
            // since we can't capture the function var without rewritting the _fillOrderAccounting inside the test
            emit OrderFill(order.recipient, index, fillAmount, receivedAmount, 0);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
            assertEq(issuer.getUnfilledAmount(id), orderAmount - fillAmount);
            // balances after
            assertEq(paymentToken.balanceOf(user), userPaymentBefore + receivedAmount - feesEarned);
            assertEq(token.balanceOf(address(issuer)), issuerAssetBefore - fillAmount);
            assertEq(paymentToken.balanceOf(operator), operatorPaymentBefore - receivedAmount);
            assertEq(paymentToken.balanceOf(treasury), feesEarned);
            if (fillAmount == orderAmount) {
                assertEq(issuer.numOpenOrders(), 0);
                assertEq(issuer.getTotalReceived(id), 0);
                assertEq(uint8(issuer.getOrderStatus(id)), uint8(IOrderProcessor.OrderStatus.FULFILLED));
            } else {
                assertEq(issuer.getTotalReceived(id), receivedAmount);
                assertEq(uint8(issuer.getOrderStatus(id)), uint8(IOrderProcessor.OrderStatus.ACTIVE));
            }
        }
    }

    function testFulfillOrder(
        uint256 orderAmount,
        uint256 firstFillAmount,
        uint256 firstReceivedAmount,
        uint256 receivedAmount
    ) public {
        vm.assume(orderAmount > 0);
        vm.assume(firstFillAmount > 0);
        vm.assume(firstFillAmount <= orderAmount);
        vm.assume(firstReceivedAmount <= receivedAmount);

        IOrderProcessor.Order memory order = dummyOrder;
        order.assetTokenQuantity = orderAmount;

        token.mint(user, orderAmount);
        vm.prank(user);
        token.approve(address(issuer), orderAmount);

        vm.prank(user);
        uint256 index = issuer.requestOrder(order);

        paymentToken.mint(operator, receivedAmount);
        vm.prank(operator);
        paymentToken.approve(address(issuer), receivedAmount);

        bytes32 id = issuer.getOrderId(order.recipient, index);
        uint256 feesEarned = 0;
        if (receivedAmount > 0) {
            if (receivedAmount <= flatFee) {
                feesEarned = receivedAmount;
            } else {
                feesEarned = flatFee + PrbMath.mulDiv18(receivedAmount - flatFee, percentageFeeRate);
            }
        }

        // balances before
        uint256 userPaymentBefore = paymentToken.balanceOf(user);
        uint256 operatorPaymentBefore = paymentToken.balanceOf(operator);
        if (firstFillAmount < orderAmount) {
            uint256 secondFillAmount = orderAmount - firstFillAmount;
            uint256 secondReceivedAmount = receivedAmount - firstReceivedAmount;
            // first fill
            vm.expectEmit(true, true, true, false);
            emit OrderFill(order.recipient, index, firstFillAmount, firstReceivedAmount, 0);
            vm.prank(operator);
            issuer.fillOrder(order, index, firstFillAmount, firstReceivedAmount);
            assertEq(issuer.getUnfilledAmount(id), orderAmount - firstFillAmount);
            assertEq(issuer.numOpenOrders(), 1);
            assertEq(issuer.getTotalReceived(id), firstReceivedAmount);

            // second fill
            vm.expectEmit(true, true, true, true);
            emit OrderFulfilled(order.recipient, index);
            vm.prank(operator);
            issuer.fillOrder(order, index, secondFillAmount, secondReceivedAmount);
        } else {
            vm.expectEmit(true, true, true, true);
            emit OrderFulfilled(order.recipient, index);
            vm.prank(operator);
            issuer.fillOrder(order, index, orderAmount, receivedAmount);
        }
        // order closed
        assertEq(issuer.getUnfilledAmount(id), 0);
        assertEq(issuer.numOpenOrders(), 0);
        assertEq(issuer.getTotalReceived(id), 0);
        // balances after
        // Fees may be k - 1 (k == number of fills) off due to rounding
        assertApproxEqAbs(paymentToken.balanceOf(user), userPaymentBefore + receivedAmount - feesEarned, 1);
        assertEq(paymentToken.balanceOf(address(issuer)), 0);
        assertEq(token.balanceOf(address(issuer)), 0);
        assertEq(paymentToken.balanceOf(operator), operatorPaymentBefore - receivedAmount);
        assertApproxEqAbs(paymentToken.balanceOf(treasury), feesEarned, 1);
        assertEq(uint8(issuer.getOrderStatus(id)), uint8(IOrderProcessor.OrderStatus.FULFILLED));
    }

    function testCancelOrder(uint256 orderAmount, uint256 fillAmount, uint256 receivedAmount, string calldata reason)
        public
    {
        vm.assume(orderAmount > 0);
        vm.assume(fillAmount < orderAmount);

        IOrderProcessor.Order memory order = dummyOrder;
        order.assetTokenQuantity = orderAmount;

        token.mint(user, orderAmount);
        vm.prank(user);
        token.approve(address(issuer), orderAmount);

        vm.prank(user);
        uint256 index = issuer.requestOrder(order);
        bytes32 id = issuer.getOrderId(order.recipient, index);

        uint256 feesEarned = 0;
        if (fillAmount > 0) {
            if (receivedAmount > 0) {
                if (receivedAmount <= flatFee) {
                    feesEarned = receivedAmount;
                } else {
                    feesEarned = flatFee + PrbMath.mulDiv18(receivedAmount - flatFee, percentageFeeRate);
                }
            }

            paymentToken.mint(operator, receivedAmount);
            vm.prank(operator);
            paymentToken.approve(address(issuer), receivedAmount);

            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
            assertEq(issuer.getTotalReceived(id), receivedAmount);
        }

        // balances before
        vm.expectEmit(true, true, true, true);
        emit OrderCancelled(order.recipient, index, reason);
        vm.prank(operator);
        issuer.cancelOrder(order, index, reason);
        // balances after
        assertEq(paymentToken.balanceOf(address(issuer)), 0);
        assertEq(token.balanceOf(address(issuer)), 0);
        if (fillAmount > 0) {
            uint256 escrow = orderAmount - fillAmount;
            assertEq(paymentToken.balanceOf(user), receivedAmount - feesEarned);
            assertEq(token.balanceOf(user), escrow);
            assertEq(paymentToken.balanceOf(treasury), feesEarned);
            assertEq(issuer.getTotalReceived(id), 0);
        } else {
            assertEq(token.balanceOf(user), orderAmount);
        }
        assertEq(uint8(issuer.getOrderStatus(id)), uint8(IOrderProcessor.OrderStatus.CANCELLED));
    }
}
