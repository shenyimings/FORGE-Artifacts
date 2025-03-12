// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "./resources/FakePaymentToken.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract paymentSplitterTest is Test {
    FakePaymentToken token;

    function setUp() public {
        token = new FakePaymentToken(type(uint256).max, 18);
    }

    function testVariableSplit(uint8 shares0, uint8 shares1, uint128 amount) public {
        vm.assume(shares0 > 0);
        vm.assume(shares1 > 0);
        vm.assume(amount > uint128(shares0) + shares1);
        address[] memory payees = new address[](2);
        payees[0] = address(0x1);
        payees[1] = address(0x2);
        uint256[] memory shares = new uint256[](2);
        shares[0] = shares0; // 80%
        shares[1] = shares1; // 20%
        PaymentSplitter splitter = new PaymentSplitter(payees, shares);

        // send amount tokens to the splitter
        token.transfer(address(splitter), amount);

        // pull share for address 1
        assertEq(token.balanceOf(payees[0]), 0);
        splitter.release(token, payees[0]);
        assertEq(token.balanceOf(payees[0]), (uint256(amount) * shares0) / (uint256(shares0) + shares1));

        // pull share for address 2
        assertEq(token.balanceOf(payees[1]), 0);
        splitter.release(token, payees[1]);
        assertEq(token.balanceOf(payees[1]), (uint256(amount) * shares1) / (uint256(shares0) + shares1));
    }

    function testFixedSplit() public {
        address[] memory payees = new address[](2);
        payees[0] = address(0x1);
        payees[1] = address(0x2);
        uint256[] memory shares = new uint256[](2);
        shares[0] = 8; // 80%
        shares[1] = 2; // 20%
        PaymentSplitter splitter = new PaymentSplitter(payees, shares);

        // send 100 tokens to the splitter
        token.transfer(address(splitter), 100e18);

        // pull share for address 1
        assertEq(token.balanceOf(payees[0]), 0);
        splitter.release(token, payees[0]);
        assertEq(token.balanceOf(payees[0]), 80e18);

        // pull share for address 2
        assertEq(token.balanceOf(payees[1]), 0);
        splitter.release(token, payees[1]);
        assertEq(token.balanceOf(payees[1]), 20e18);
    }

    function testMultiplePayments() public {
        address[] memory payees = new address[](2);
        payees[0] = address(0x1);
        payees[1] = address(0x2);
        uint256[] memory shares = new uint256[](2);
        shares[0] = 8; // 80%
        shares[1] = 2; // 20%
        PaymentSplitter splitter = new PaymentSplitter(payees, shares);

        // send 100 tokens to the splitter
        token.transfer(address(splitter), 100e18);

        // pull share for address 1
        assertEq(token.balanceOf(payees[0]), 0);
        splitter.release(token, payees[0]);
        assertEq(token.balanceOf(payees[0]), 80e18);

        // send another 300 tokens to the splitter
        token.transfer(address(splitter), 300e18);

        // pull full share for address 2
        assertEq(token.balanceOf(payees[1]), 0);
        splitter.release(token, payees[1]);
        assertEq(token.balanceOf(payees[1]), (((100 + 300) * 20) / 100) * 1e18);

        // pull remaining share for address 1
        splitter.release(token, payees[0]);
        assertEq(token.balanceOf(payees[0]), (((100 + 300) * 80) / 100) * 1e18);
    }

    function testAnyoneCanTriggerPayout(address rando) public {
        address[] memory payees = new address[](2);
        payees[0] = address(0x1);
        payees[1] = address(0x2);
        uint256[] memory shares = new uint256[](2);
        shares[0] = 1;
        shares[1] = 1;
        PaymentSplitter splitter = new PaymentSplitter(payees, shares);

        // send 100 tokens to the splitter
        token.transfer(address(splitter), 100e18);

        // pull share for address 1
        assertEq(token.balanceOf(payees[0]), 0);
        vm.prank(rando);
        splitter.release(token, payees[0]);
        assertEq(token.balanceOf(payees[0]), 50e18);
    }

    function testLockingFunds() public {
        uint256 shares0 = 100e6;
        uint256 shares1 = 100e6;
        uint256 amount = type(uint256).max / 1e6;

        // note how amount * shares0 > type(uint128).max

        address[] memory payees = new address[](2);
        payees[0] = address(0x1);
        payees[1] = address(0x2);
        uint256[] memory shares = new uint256[](2);
        shares[0] = shares0; // 80%
        shares[1] = shares1; // 20%
        PaymentSplitter splitter = new PaymentSplitter(payees, shares);

        // send amount tokens to the splitter
        token.transfer(address(splitter), amount);

        assertEq(token.balanceOf(payees[0]), 0);

        // try pulling share for address 1
        // this will fail because it overflows during the calculation inside PaymentSplitter
        vm.expectRevert();
        splitter.release(token, payees[0]);

        // should be fine for our use case though: the sum of all fees will always be significantly less than the total supply,
        // and we will choose a sum of shares of less than 1000.
    }
}
