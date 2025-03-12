// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Polynomials} from "../libs/Polynomials.sol";
import {Polynomial} from "../libs/Polynomials.sol";

contract PolynomialsTest {
    function eval6(Polynomial memory p, uint256 value) public pure returns (uint256) {
        return Polynomials.eval6(p, value);
    }

    function eval5(Polynomial memory p, uint256 value) public pure returns (uint256) {
        return Polynomials.eval5(p, value);
    }

    function eval4(Polynomial memory p, uint256 value) public pure returns (uint256) {
        return Polynomials.eval4(p, value);
    }

    function eval3(Polynomial memory p, uint256 value) public pure returns (uint256) {
        return Polynomials.eval3(p, value);
    }
}
