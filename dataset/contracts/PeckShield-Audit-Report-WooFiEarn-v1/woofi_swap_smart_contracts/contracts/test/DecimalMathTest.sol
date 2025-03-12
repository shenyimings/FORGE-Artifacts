// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

import '../libraries/DecimalMath.sol';

contract DecimalMathTest {
    function mulFloor(uint256 target, uint256 d) external pure returns (uint256) {
        return DecimalMath.mulFloor(target, d);
    }

    function mulCeil(uint256 target, uint256 d) external pure returns (uint256) {
        return DecimalMath.mulCeil(target, d);
    }

    function divFloor(uint256 target, uint256 d) external pure returns (uint256) {
        return DecimalMath.divFloor(target, d);
    }

    function divCeil(uint256 target, uint256 d) external pure returns (uint256) {
        return DecimalMath.divCeil(target, d);
    }

    function reciprocalFloor(uint256 target) external pure returns (uint256) {
        return DecimalMath.reciprocalFloor(target);
    }

    function reciprocalCeil(uint256 target) external pure returns (uint256) {
        return DecimalMath.reciprocalCeil(target);
    }
}
