// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Library for counter with initial value of non zero.
 */
library Counter {
    struct Minted {
        uint256 _inner;
    }

    /**
     * @dev Save `type(uint256).max` to save on gas costs for the first mint.
     * Zero to non-zero gas costs are less than zero to non-zero.
     */
    function initialize(Minted storage minted) internal {
        minted._inner = type(uint256).max;
    }

    /**
     * @dev Add `count` to the internal value.
     */
    function increment(Minted storage minted, uint256 count) internal {
        require(count > 0, "Counter: count must be greater than 0");
        uint256 t = minted._inner;
        uint256 incremented = t == type(uint256).max ? count : t + count;
        require(incremented != type(uint256).max, "Counter: overflow");
        minted._inner = incremented;
    }

    /**
     * @dev Returns the internal value.
     */
    function current(Minted storage minted) internal view returns (uint256) {
        uint256 t = minted._inner;
        return t == type(uint256).max ? 0 : t;
    }
}
