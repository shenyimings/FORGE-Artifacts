// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {MockToken} from "../utils/mocks/MockToken.sol";
import {OrderProcessor} from "../../src/orders/OrderProcessor.sol";
import "../utils/mocks/MockdShareFactory.sol";
import "../../src/orders/BuyProcessor.sol";
import "../../src/orders/IOrderProcessor.sol";
import {TokenLockCheck, ITokenLockCheck} from "../../src/TokenLockCheck.sol";
import {NumberUtils} from "../utils/NumberUtils.sol";
import {FeeLib} from "../../src/common/FeeLib.sol";

contract LimitBuyProcessorTest is Test {
    event OrderRequested(address indexed recipient, uint256 indexed index, IOrderProcessor.Order order);
    event OrderFill(
        address indexed recipient, uint256 indexed index, uint256 fillAmount, uint256 receivedAmount, uint256 feesPaid
    );

    MockdShareFactory tokenFactory;
    dShare token;
    TokenLockCheck tokenLockCheck;
    BuyProcessor issuer;
    MockToken paymentToken;

    uint256 userPrivateKey;
    address user;

    address constant operator = address(3);
    address constant treasury = address(4);

    uint256 flatFee;
    uint24 percentageFeeRate;

    function setUp() public {
        userPrivateKey = 0x01;
        user = vm.addr(userPrivateKey);

        tokenFactory = new MockdShareFactory();
        token = tokenFactory.deploy("Dinari Token", "dTKN");
        paymentToken = new MockToken("Money", "$");

        tokenLockCheck = new TokenLockCheck(address(paymentToken), address(paymentToken));

        issuer = new BuyProcessor(address(this), treasury, 1 ether, 5_000, tokenLockCheck);

        (flatFee, percentageFeeRate) = issuer.getFeeRatesForOrder(user, false, address(paymentToken));

        token.grantRole(token.MINTER_ROLE(), address(this));
        token.grantRole(token.MINTER_ROLE(), address(issuer));

        issuer.grantRole(issuer.PAYMENTTOKEN_ROLE(), address(paymentToken));
        issuer.grantRole(issuer.ASSETTOKEN_ROLE(), address(token));
        issuer.grantRole(issuer.OPERATOR_ROLE(), operator);
    }

    function createLimitOrder(uint256 orderAmount, uint256 price)
        internal
        view
        returns (IOrderProcessor.Order memory order)
    {
        order = IOrderProcessor.Order({
            recipient: user,
            assetToken: address(token),
            paymentToken: address(paymentToken),
            sell: false,
            orderType: IOrderProcessor.OrderType.LIMIT,
            assetTokenQuantity: 0,
            paymentTokenQuantity: orderAmount,
            price: price,
            tif: IOrderProcessor.TIF.GTC
        });
    }

    function testRequestOrderLimit(uint256 orderAmount, uint256 _price) public {
        uint256 fees = FeeLib.estimateTotalFees(flatFee, percentageFeeRate, orderAmount);
        vm.assume(!NumberUtils.addCheckOverflow(orderAmount, fees));
        IOrderProcessor.Order memory order = createLimitOrder(orderAmount, _price);

        paymentToken.mint(user, order.paymentTokenQuantity + fees);
        vm.startPrank(user);
        paymentToken.approve(address(issuer), order.paymentTokenQuantity + fees);

        if (orderAmount == 0) {
            vm.expectRevert(OrderProcessor.ZeroValue.selector);
            issuer.requestOrder(order);
        } else if (_price == 0) {
            vm.expectRevert(BuyProcessor.LimitPriceNotSet.selector);
            issuer.requestOrder(order);
        } else {
            uint256 userBalanceBefore = paymentToken.balanceOf(user);
            uint256 issuerBalanceBefore = paymentToken.balanceOf(address(issuer));
            vm.expectEmit(true, true, true, true);
            emit OrderRequested(user, 0, order);
            uint256 index = issuer.requestOrder(order);
            bytes32 id = issuer.getOrderId(order.recipient, index);
            assertEq(index, 0);
            assertEq(uint8(issuer.getOrderStatus(id)), uint8(IOrderProcessor.OrderStatus.ACTIVE));
            assertEq(issuer.getUnfilledAmount(id), order.paymentTokenQuantity);
            assertEq(issuer.numOpenOrders(), 1);
            // balances after
            assertEq(paymentToken.balanceOf(address(user)), userBalanceBefore - (order.paymentTokenQuantity + fees));
            assertEq(paymentToken.balanceOf(address(issuer)), issuerBalanceBefore + (order.paymentTokenQuantity + fees));
        }
        vm.stopPrank();
    }

    function testFillBuyOrderLimit(uint256 orderAmount, uint256 fillAmount, uint256 receivedAmount, uint256 _price)
        public
    {
        vm.assume(_price > 0);
        vm.assume(orderAmount > 0);
        vm.assume(!NumberUtils.mulDivCheckOverflow(fillAmount, 1 ether, _price));
        uint256 fees = FeeLib.estimateTotalFees(flatFee, percentageFeeRate, orderAmount);
        vm.assume(!NumberUtils.addCheckOverflow(orderAmount, fees));

        IOrderProcessor.Order memory order = createLimitOrder(orderAmount, _price);

        uint256 feesEarned = 0;
        if (fillAmount > 0) {
            feesEarned = flatFee + PrbMath.mulDiv(fees - flatFee, fillAmount, order.paymentTokenQuantity);
        }

        paymentToken.mint(user, order.paymentTokenQuantity + fees);
        vm.prank(user);
        paymentToken.approve(address(issuer), order.paymentTokenQuantity + fees);

        vm.prank(user);
        uint256 index = issuer.requestOrder(order);

        bytes32 id = issuer.getOrderId(order.recipient, index);
        if (fillAmount == 0) {
            vm.expectRevert(OrderProcessor.ZeroValue.selector);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
        } else if (fillAmount > orderAmount) {
            vm.expectRevert(OrderProcessor.AmountTooLarge.selector);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
        } else if (receivedAmount < PrbMath.mulDiv(fillAmount, 1 ether, order.price)) {
            vm.expectRevert(BuyProcessor.OrderFillBelowLimitPrice.selector);
            vm.prank(operator);
            issuer.fillOrder(order, index, fillAmount, receivedAmount);
        } else {
            // balances before
            uint256 userAssetBefore = token.balanceOf(user);
            uint256 issuerPaymentBefore = paymentToken.balanceOf(address(issuer));
            uint256 operatorPaymentBefore = paymentToken.balanceOf(operator);
            vm.assume(fillAmount < orderAmount);
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
                // balances after
                assertEq(token.balanceOf(address(user)), userAssetBefore + receivedAmount);
                assertEq(paymentToken.balanceOf(address(issuer)), issuerPaymentBefore - fillAmount - feesEarned);
                assertEq(paymentToken.balanceOf(operator), operatorPaymentBefore + fillAmount);
                assertEq(paymentToken.balanceOf(treasury), feesEarned);
            }
        }
    }
}
