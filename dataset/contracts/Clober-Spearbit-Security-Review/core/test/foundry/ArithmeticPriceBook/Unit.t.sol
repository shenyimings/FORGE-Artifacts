// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../contracts/ArithmeticPriceBook.sol";

contract ArithmeticPriceBookUnitTest is Test {
    uint128 public constant A = 10**14;
    uint128 public constant D = 10**14;

    ArithmeticPriceBook priceBook;

    function setUp() public {
        priceBook = new ArithmeticPriceBook(A, D);
    }

    function testIndexToPrice() public {
        assertEq(priceBook.indexToPrice(0), A);
        assertEq(priceBook.indexToPrice(5), A + 5 * D);
        assertEq(priceBook.indexToPrice(type(uint16).max), A + type(uint16).max * D);
    }

    function _testPriceToIndex(
        uint256 price,
        bool roundingUp,
        uint16 expectedIndex
    ) private {
        (uint16 priceIndex, uint256 correctedPrice) = priceBook.priceToIndex(price, roundingUp);
        assertEq(priceIndex, expectedIndex);
        assertEq(correctedPrice, priceBook.indexToPrice(expectedIndex));
    }

    function testPriceToIndex() public {
        _testPriceToIndex(A, false, 0);
        _testPriceToIndex(A + 5 * D, false, 5);

        _testPriceToIndex(A + 5 * D - 1, false, 4);
        _testPriceToIndex(A + 5 * D - 1, true, 5);
        _testPriceToIndex(A + 5 * D + 1, false, 5);
        _testPriceToIndex(A + 5 * D + 1, true, 6);

        _testPriceToIndex(A + type(uint16).max * D, false, type(uint16).max);
        _testPriceToIndex(A + type(uint16).max * D - 1, false, type(uint16).max - 1);
    }

    function testRevertPriceToIndex() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE));
        priceBook.priceToIndex(A - 1, true);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE));
        priceBook.priceToIndex(A - 1, false);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE));
        priceBook.priceToIndex(A + (2**16) * D, true);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE));
        priceBook.priceToIndex(A + (2**16) * D, false);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE));
        priceBook.priceToIndex(A + (2**16) * D - 1, true);
    }

    function testPriceUpperBound() public {
        uint256 maxPrice = priceBook.indexToPrice(priceBook.maxPriceIndex());
        assertGe(priceBook.priceUpperBound(), maxPrice);
    }
}
