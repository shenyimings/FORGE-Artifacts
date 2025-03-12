// SPDX-License-Identifier: GPL-2.0

pragma solidity 0.7.6;

library MathHelper {
    ///@dev cast uint24 to int24
    function fromUint24ToInt24(uint24 value) internal pure returns (int24) {
        require(
            uint256(value) <= uint256(type(int24).max),
            "MathHelper::fromUint24ToInt24: value doesn't fit in 24 bits"
        );
        return int24(value);
    }

    ///@dev cast int24 to uint24
    function fromInt24ToUint24(int24 value) internal pure returns (uint24) {
        require(
            int256(value) <= int256(type(uint24).max),
            "MathHelper::fromInt24ToUint24: value doesn't fit in 24 bits"
        );
        return value >= 0 ? uint24(value) : uint24(-value);
    }

    ///@dev cast int56 to uint256
    function fromInt56ToUint256(int56 value) internal pure returns (uint256) {
        return value >= 0 ? uint256(value) : uint256(-value);
    }

    ///@dev cast uint256 to uint24
    function fromUint256ToUint24(uint256 value) internal pure returns (uint24) {
        require(value <= uint256(type(uint24).max), "MathHelper::fromUint256ToUint24: value doesn't fit in 24 bits");
        return uint24(value);
    }

    ///@dev cast uint256 to int24
    function fromUint256ToInt24(uint256 value) internal pure returns (int24) {
        require(value <= uint256(type(int24).max), "MathHelper::fromUint256ToInt24: value doesn't fit in 24 bits");
        return int24(value);
    }
}
