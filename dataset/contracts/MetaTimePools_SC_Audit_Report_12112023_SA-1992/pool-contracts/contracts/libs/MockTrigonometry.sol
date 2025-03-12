// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./Trigonometry.sol";

/**
 * @title MockTrigonometry
 * @dev A mock contract that provides trigonometric functions by delegating the calls to the Trigonometry library.
 */
contract MockTrigonometry {
    /**
     * @dev Calculates the sine of the given angle.
     * @param _angle The angle in radians.
     * @return The sine value as an int256.
     */
    function sin(uint256 _angle) public pure returns (int256) {
        return Trigonometry.sin(_angle);
    }

    /**
     * @dev Calculates the cosine of the given angle.
     * @param _angle The angle in radians.
     * @return The cosine value as an int256.
     */
    function cos(uint256 _angle) public pure returns (int256) {
        return Trigonometry.cos(_angle);
    }
}
