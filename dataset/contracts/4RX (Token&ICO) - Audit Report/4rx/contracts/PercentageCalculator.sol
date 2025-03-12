// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";


contract PercentageCalculator {
    using SafeMath for uint;

    uint public constant PERCENT_MULTIPLIER = 10000;

    function _calcPercentage(uint amount, uint basisPoints) internal pure returns (uint) {
        require(basisPoints >= 0);
        return amount.mul(basisPoints).div(PERCENT_MULTIPLIER);
    }

    function _calcBasisPoints(uint base, uint interest) internal pure returns (uint) {
        return interest.mul(PERCENT_MULTIPLIER).div(base);
    }
}
