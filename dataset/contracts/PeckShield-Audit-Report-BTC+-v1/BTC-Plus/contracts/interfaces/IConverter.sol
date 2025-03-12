// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @dev Interfaces for converter.
 */
interface IConverter {

    function convert(address _from, address _to, uint256 _fromAmount, uint256 _toAmount) external;
}