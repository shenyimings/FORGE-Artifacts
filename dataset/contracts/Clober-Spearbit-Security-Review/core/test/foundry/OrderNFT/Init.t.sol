// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../contracts/interfaces/CloberOrderNFT.sol";
import "../../../contracts/OrderNFT.sol";

contract OrderNFTInitUnitTest is Test {
    OrderNFT orderToken;

    function setUp() public {
        orderToken = new OrderNFT(address(this), address(0x456));
    }

    function testInit() public {
        orderToken.init("abc", "AAA", address(0x123));
        assertEq(orderToken.name(), "abc", "NAME");
        assertEq(orderToken.symbol(), "AAA", "SYMBOL");
        assertEq(orderToken.market(), address(0x123), "MARKET");
    }

    function testInitWithZeroOrderBookAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        orderToken.init("abc", "AAA", address(0));
    }

    function testInitAlreadyInitialized() public {
        orderToken.init("abc", "AAA", address(0x123));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderToken.init("abc", "AAA", address(0x234));
    }
}
