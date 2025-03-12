// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRandomGenerator {
    /**
     * Requests randomness from a user-provided seed
     */
    function getRandomNumber() external returns (uint256);
}
