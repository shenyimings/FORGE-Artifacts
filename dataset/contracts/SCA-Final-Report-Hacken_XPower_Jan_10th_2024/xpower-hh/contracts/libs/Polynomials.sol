// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Power} from "./Power.sol";

struct Polynomial {
    uint256[] array;
}

library Polynomials {
    /**
     * @return value evaluated with {(value+[5-4])*[3/2]+[1-0]}^{[6]/256}
     *
     * Evaluates a `value` using a linear function -- defined by
     * the provided polynomial coefficients.
     */
    function eval6(Polynomial memory p, uint256 value) internal pure returns (uint256) {
        uint256 delta = value + p.array[5] - p.array[4];
        uint256 ratio = Math.mulDiv(delta, p.array[3], p.array[2]);
        uint256 shift = ratio + p.array[1] - p.array[0];
        return Power.raise(shift, p.array[6]);
    }

    /**
     * @return value evaluated with {(value+[4-3])*[2/1]+[0]}^{[5]/256}
     *
     * Evaluates a `value` using a linear function -- defined by
     * the provided polynomial coefficients.
     */
    function eval5(Polynomial memory p, uint256 value) internal pure returns (uint256) {
        uint256 delta = value + p.array[4] - p.array[3];
        uint256 ratio = Math.mulDiv(delta, p.array[2], p.array[1]);
        return Power.raise(ratio + p.array[0], p.array[5]);
    }

    /**
     * @return value evaluated with {(value)*[3/2]+[1-0]}^{[4]/256}
     *
     * Evaluates a `value` using a linear function -- defined by
     * the provided polynomial coefficients.
     */
    function eval4(Polynomial memory p, uint256 value) internal pure returns (uint256) {
        uint256 ratio = Math.mulDiv(value, p.array[3], p.array[2]);
        uint256 shift = ratio + p.array[1] - p.array[0];
        return Power.raise(shift, p.array[4]);
    }

    /**
     * @return value evaluated with {(value)*[2/1]+[0]}^{[3]/256}
     *
     * Evaluates a `value` using a linear function -- defined by
     * the provided polynomial coefficients.
     */
    function eval3(Polynomial memory p, uint256 value) internal pure returns (uint256) {
        uint256 ratio = Math.mulDiv(value, p.array[2], p.array[1]);
        return Power.raise(ratio + p.array[0], p.array[3]);
    }
}
