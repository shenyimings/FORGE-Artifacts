// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { LibSqrtPriceX96 } from "src/libraries/LibSqrtPriceX96.sol";

contract LibSqrtPriceX96UnitTest is Test {
  function testCorrectness_DecodeSqrtPriceX96() public {
    // ethereum ETH-USDT pool
    assertEq(LibSqrtPriceX96.decodeSqrtPriceX96(3400720895387849494853354, 18, 6), 1842395279000000000000);
    // ethereum USDC-ETH pool
    assertEq(LibSqrtPriceX96.decodeSqrtPriceX96(1845593816970823776635053551616999, 6, 18), 542641601304412);
    // Should be able to handle max uint160
    assertEq(
      LibSqrtPriceX96.decodeSqrtPriceX96(type(uint160).max, 18, 18),
      340282366920938463463374607431768211455999999999534338712
    );
    assertEq(LibSqrtPriceX96.decodeSqrtPriceX96(type(uint160).max, 1, 18), 3402823669209384634633746074317682114559);
    assertEq(
      LibSqrtPriceX96.decodeSqrtPriceX96(type(uint160).max, 18, 1),
      34028236692093846346337460743176821145599999999953433871200000000000000000
    );
  }

  function testCorrectness_EncodeSqrtPriceX96() public {
    // sqrt calculation use estimation so there is minor precision loss
    // ethereum ETH-USDT pool
    // Correct result is 3400356069087804511330694
    assertEq(LibSqrtPriceX96.encodeSqrtPriceX96(1842 ether, 18, 6), 3400314278787196840839719);
    // ethereum USDC-ETH pool
    // Correct result is 1846013066822912038042547923730247
    assertEq(LibSqrtPriceX96.encodeSqrtPriceX96(542888165038002, 6, 18), 1846013066822847329831664791270428);
  }

  function testCorrectness_DecodeThenEncode_ErrorShouldBeNegligible() public {
    uint160 start = 3400720895387849494853354;
    uint256 decoded = LibSqrtPriceX96.decodeSqrtPriceX96(start, 18, 6);
    uint160 encoded = LibSqrtPriceX96.encodeSqrtPriceX96(decoded, 18, 6);
    assertApproxEqRel(start, encoded, 5e12); // within 0.0005% error
  }
}
