// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Constants} from "../libs/Constants.sol";

/**
 * @title Rug pull protection
 */
library Rpp {
    /** validate params: w.r.t. Polynomial.eval3 */
    function checkArray(uint256[] memory array) internal pure {
        require(array.length == 4, "invalid array.length");
        // eliminate possibility of division-by-zero
        require(array[1] > 0, "invalid array[1] == 0");
        // eliminate possibility of all-zero values
        require(array[2] > 0, "invalid array[2] == 0");
    }

    /** validate change: 0.5 <= next / last <= 2.0 or next <= unit */
    function checkValue(uint256 next, uint256 last, uint256 unit) internal pure {
        if (next < last) {
            require(last <= 2 * next, "invalid change: too small");
        }
        if (next > last && last > 0) {
            require(next <= 2 * last, "invalid change: too large");
        }
        if (next > last && last == 0) {
            require(next <= unit, "invalid change: too large");
        }
    }

    /** validate change: invocation frequency at most once per month */
    function checkStamp(uint256 next, uint256 last) internal pure {
        if (last > 0) {
            require(next > Constants.MONTH + last, "invalid change: too frequent");
        }
    }
}
