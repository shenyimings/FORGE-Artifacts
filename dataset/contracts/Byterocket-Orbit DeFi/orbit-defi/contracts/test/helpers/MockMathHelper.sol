// SPDX-License-Identifier: GPL-2.0

pragma solidity 0.7.6;
import '../../helpers/MathHelper.sol';

contract MockMathHelper {
    ///@dev cast uint24 to int24
    function fromUint24ToInt24(uint24 value) public pure returns (int24) {
        return MathHelper.fromUint24ToInt24(value);
    }

    ///@dev cast int24 to uint24
    function fromInt24ToUint24(int24 value) public pure returns (uint24) {
        return MathHelper.fromInt24ToUint24(value);
    }

    ///@dev cast uint256 to uint24
    function fromUint256ToUint24(uint256 value) public pure returns (uint24) {
        return MathHelper.fromUint256ToUint24(value);
    }

    ///@dev cast uint256 to int24
    function fromUint256ToInt24(uint256 value) public pure returns (int24) {
        return MathHelper.fromUint256ToInt24(value);
    }
}
