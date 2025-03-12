// SPDX-License-Identifier: GPL-2.0

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMath {
    int24 private constant _INT_24_MIN = type(int24).min;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int24 a, int24 b) internal pure returns (int24) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT_24_MIN), 'SignedSafeMath::mul: multiplication overflow');

        int24 c = a * b;
        require(c / a == b, 'SignedSafeMath::mul: multiplication overflow');

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(int24 a, int24 b) internal pure returns (int24) {
        require(b != 0, 'SignedSafeMath::div: division by zero');
        require(!(b == -1 && a == _INT_24_MIN), 'SignedSafeMath::div: division overflow');

        int24 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int24 a, int24 b) internal pure returns (int24) {
        int24 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), 'SignedSafeMath::sub: subtraction overflow');

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int24 a, int24 b) internal pure returns (int24) {
        int24 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), 'SignedSafeMath::add: addition overflow');

        return c;
    }
}
