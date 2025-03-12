// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {MockToken} from "../utils/mocks/MockToken.sol";
import {OrderProcessor} from "../../src/orders/OrderProcessor.sol";
import "../utils/mocks/MockdShareFactory.sol";
import "../../src/orders/SellProcessor.sol";
import "../../src/orders/IOrderProcessor.sol";
import {TokenLockCheck, ITokenLockCheck} from "../../src/TokenLockCheck.sol";
import {FeeLib} from "../../src/common/FeeLib.sol";

contract LimitSellProcessorTest is Test {
    event OrderRequested(address indexed recipient, uint256 indexed index, IOrderProcessor.Order order);
    event OrderFill(
        address indexed recipient, uint256 indexed index, uint256 fillAmount, uint256 receivedAmount, uint256 feesPaid
    );

    MockdShareFactory tokenFactory;
    dShare token;
    TokenLockCheck tokenLockCheck;
    SellProcessor issuer;
    MockToken paymentToken;

    uint256 userPrivateKey;
    address user;

    address constant operator = address(3);
    address constant treasury = address(4);

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
    }

    function createOrder(uint256 orderAmount, uint256 price)
        internal
        view
        returns (IOrderProcessor.Order memory order)
    {
        order = IOrderProcessor.Order({
            recipient: user,
            assetToken: address(token),
            paymentToken: address(paymentToken),
            sell: true,
            orderType: IOrderProcessor.OrderType.LIMIT,
            assetTokenQuantity: orderAmount,
            paymentTokenQuantity: 0,
            price: price,
            tif: IOrderProcessor.TIF.GTC
        });
    }

    function testRequestOrderLimit(uint256 orderAmount, uint256 _price) public {
        IOrderProcessor.Order memory order = createOrder(orderAmount, _price);

        token.mint(user, orderAmount);
        vm.prank(user);
        token.approve(address(issuer), orderAmount);

        bytes32 id = issuer.getOrderId(order.recipient, 0);
        if (orderAmount == 0) {
            vm.expectRevert(OrderProcessor.ZeroValue.selector);
            vm.prank(user);
            issuer.requestOrder(order);
        } else if (_price == 0) {
            vm.expectRevert(SellProcessor.LimitPriceNotSet.selector);
            vm.prank(user);
            issuer.requestOrder(order);
        } else {
            // balances before
            uint256 userBalanceBefore = token.balanceOf(user);
            uint256 issuerBalanceBefore = token.balanceOf(address(issuer));
            vm.expectEmit(true, true, true, true);
            emit OrderRequested(user, 0, order);
            vm.prank(user);
            uint256 index = issuer.requestOrder(order);
            assertEq(index, 0);
            assertEq(uint8(issuer.getOrderStatus(id)), uint8(IOrderProcessor.OrderStatus.ACTIVE));
            assertEq(issuer.getUnfilledAmount(id), orderAmount);
            assertEq(issuer.numOpenOrders(), 1);
            assertEq(token.balanceOf(address(issuer)), orderAmount);
            // balances after
            assertEq(token.balanceOf(user), userBalanceBefore - orderAmount);
            assertEq(token.balanceOf(address(issuer)), issuerBalanceBefore + orderAmount);
        }
    }

    function testFillSellOrderLimit(uint256 orderAmount, uint256 fillAmount, uint256 receivedAmount, uint256 _price)
        public
    {
        vm.assume(orderAmount > 0);
        vm.assume(_price > 0 && _price < 2 ** 128 - 1);
        vm.assume(fillAmount < 2 ** 128 - 1);
        vm.assume(receivedAmount < 2 ** 128 - 1);

        IOrderProcessor.Order memory order = createOrder(orderAmount, _price);

        token.mint(user, orderAmount);
        vm.prank(user);
        token.approve(address(issuer), orderAmount);

        vm.prank(user);
        uint256 index = issuer.requestOrder(order);

        paymentToken.mint(operator, receivedAmount); // Mint paymentTokens to operator to ensure they have enough
        vm.prank(operator);
        paymentToken.approve(address(issuer), receivedAmount);

        bytes32 id = issuer.getOrderId(order.recipient, 0);
        if (fillAmount == 0) {
            vm.expectRevert(OrderProcessor.ZeroValue.selector);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
        } else if (fillAmount > orderAmount) {
            vm.expectRevert(OrderProcessor.AmountTooLarge.selector);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
        } else if (receivedAmount < PrbMath.mulDiv18(fillAmount, order.price)) {
            vm.expectRevert(SellProcessor.OrderFillAboveLimitPrice.selector);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
        } else {
            // balances before
            uint256 issuerAssetBefore = token.balanceOf(address(issuer));
            uint256 operatorPaymentBefore = paymentToken.balanceOf(operator);
            vm.expectEmit(true, true, true, false);
            // since we can't capture the function var without rewritting the _fillOrderAccounting inside the test
            emit OrderFill(order.recipient, index, fillAmount, receivedAmount, 0);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
            assertEq(issuer.getUnfilledAmount(id), orderAmount - fillAmount);
            if (fillAmount == orderAmount) {
                assertEq(issuer.numOpenOrders(), 0);
                assertEq(issuer.getTotalReceived(id), 0);
                assertEq(uint8(issuer.getOrderStatus(id)), uint8(IOrderProcessor.OrderStatus.FULFILLED));
            } else {
                assertEq(issuer.getTotalReceived(id), receivedAmount);
                assertEq(uint8(issuer.getOrderStatus(id)), uint8(IOrderProcessor.OrderStatus.ACTIVE));
                // balances after
                // assertEq(paymentToken.balanceOf(address(issuer)), issuerPaymentBefore + receivedAmount);
                assertEq(token.balanceOf(address(issuer)), issuerAssetBefore - fillAmount);
                assertEq(paymentToken.balanceOf(operator), operatorPaymentBefore - receivedAmount);
            }
        }
    }
}
