// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../core/Globals.sol";

library MathHelper {
    /// @notice percent has to be multiplied by PRECISION
    function percentage(uint256 num, uint256 percent) internal pure returns (uint256) {
        return (num * percent) / PERCENTAGE_100;
    }

    function ratio(uint256 base, uint256 num, uint256 denom) internal pure returns (uint256) {
        return (base * num) / denom;
    }

    function ratio(int256 base, int256 num, int256 denom) internal pure returns (int256) {
        return (base * num) / denom;
    }
}
