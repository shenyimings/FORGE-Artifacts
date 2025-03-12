// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

/**
 * @dev Oracle referenced by OracleProxy must implement this interface.
 */
interface OracleInterface {
    function latestAnswer() external view returns (int256);

    function decimals() external view returns (uint8);
}
