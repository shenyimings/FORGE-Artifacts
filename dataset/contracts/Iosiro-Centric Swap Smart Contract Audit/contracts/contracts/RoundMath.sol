pragma solidity 0.4.25;


/// @dev Math operations with safety checks that revert on error
library RoundMath {
    /// @dev Integer division of two numbers rounding the quotient, reverts on division by zero.
    function roundDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, 'DIVIDING_ERROR');
        uint256 c = (((a * 10) / b) + 5) / 10;
        return c;
    }

    /// @dev Integer division of two numbers ceiling the quotient, reverts on division by zero.
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, 'DIVIDING_ERROR');
        uint256 c = a / b;
        if (a % b > 0) {
            c = c + 1;
        }
        return c;
    }
}
