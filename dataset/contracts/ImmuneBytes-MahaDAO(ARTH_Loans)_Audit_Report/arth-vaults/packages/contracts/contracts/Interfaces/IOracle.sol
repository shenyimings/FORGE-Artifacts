// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface IOracle {
    function getPrice() external view returns (uint256);

    function getDecimalPrecision() external view returns (uint256);
}
