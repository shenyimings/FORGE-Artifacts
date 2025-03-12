// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

library Constants {
    /** a century in [seconds] (approximation) */
    uint256 internal constant CENTURY = 365_25 days;
    /** a year in [seconds] (approximation) */
    uint256 internal constant YEAR = CENTURY / 100;
    /** a month [seconds] (approximation) */
    uint256 internal constant MONTH = YEAR / 12;
    /** number of decimals of representation */
    uint8 internal constant DECIMALS = 18;
}
