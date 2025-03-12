// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../../contracts/GeometricPriceBook.sol";

contract GeometricPriceBookIntegrationTest is Test {
    function testCoefficients(uint128 a, uint128 r) public {
        vm.assume(a < 3 * 10**38 && r < 3 * 10**38);
        if ((uint256(r) * a) / 10**18 <= a) {
            vm.expectRevert();
            new GeometricPriceBook(a, r);
        } else {
            _testCoefficients(a, r);
        }
    }

    function _testCoefficients(uint128 a, uint128 r) internal {
        GeometricPriceBook priceBook = new GeometricPriceBook(a, r);
        uint16 maxPriceIndex = priceBook.maxPriceIndex();
        if (maxPriceIndex < 0xffff) {
            vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_PRICE_INDEX));
            priceBook.indexToPrice(maxPriceIndex + 1);
        }
        assertLe(priceBook.indexToPrice(maxPriceIndex), priceBook.priceUpperBound(), "WRONG_MAX_PRICE");
    }

    function testCoefficients() public {
        _testCoefficients(1000000, 100001 * 10**13);
        _testCoefficients(1, 2 * 10**18);
        _testCoefficients(10**5, 10001 * 10**14);
    }
}
