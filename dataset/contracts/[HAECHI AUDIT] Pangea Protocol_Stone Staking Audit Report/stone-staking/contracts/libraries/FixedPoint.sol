// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

library FixedPoint {
    uint8 internal constant Q128RES = 128;
    uint8 internal constant Q96RES = 96;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
