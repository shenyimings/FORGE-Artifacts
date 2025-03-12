// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

library Constants {
    uint16 public constant MAX_ORDER = 32768;
    uint24 public constant MAX_FEE = 500000;
    int24 public constant MIN_FEE = -500000;
    uint24 public constant TAKE_FEE = 600;
    uint24 public constant MAKE_FEE = 400;
    uint24 public constant DAO_FEE = 200000; // 20%
    uint256 public constant FEE_PRECISION = 1000000; // 1 = 0.0001%
    uint256 public constant PRICE_PRECISION = 10**18;
    uint256 public constant CLAIM_BOUNTY = 100; // in gwei unit
    uint64 public constant RAW_AMOUNT = 10;
    uint16 public constant PRICE_INDEX = 3;
    uint16 public constant LIMIT_BID_PRICE = type(uint16).max;
    uint16 public constant LIMIT_ASK_PRICE = 0;
    address public constant MAKER = address(1);
    address public constant TAKER = address(2);
    bool public constant BID = true;
    bool public constant ASK = false;
    bool public constant POST_ONLY = true;
    bool public constant EXPEND_INPUT = true;
    bool public constant EXPEND_OUTPUT = false;
}
