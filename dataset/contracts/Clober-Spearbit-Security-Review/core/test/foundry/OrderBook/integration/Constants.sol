// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

library Constants {
    uint16 public constant MAX_ORDER = 32768;
    uint24 public constant MAX_FEE = 500000;
    int24 public constant MIN_FEE = -500000;
    uint24 public constant TAKE_FEE = 600;
    uint24 public constant MAKE_FEE = 400;
    uint88 public constant QUOTE_UNIT = 10**4; // unit is 1 USDC
    uint256 public constant LARGE_ORDER_COUNT = 2 * uint256(MAX_ORDER) + 1;
    uint256 public constant FEE_PRECISION = 1000000; // 1 = 0.0001%
    uint256 public constant PRICE_PRECISION = 10**18;
    uint256 public constant CLAIM_BOUNTY = 100; // in gwei unit
    address public constant USER_A = address(1);
    address public constant USER_B = address(2);
    address public constant USER_C = address(3);
    address public constant USER_D = address(4);
    uint128 public constant ARITHMETIC_A = 10**14;
    uint128 public constant ARITHMETIC_D = 10**14;
    uint128 public constant GEOMETRIC_A = 10**10;
    uint128 public constant GEOMETRIC_R = 1001 * 10**15;
    bool public constant BID = true;
    bool public constant ASK = false;
    bool public constant POST_ONLY = true;
    bool public constant EXPEND_INPUT = true;
    bool public constant EXPEND_OUTPUT = false;
}
