// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IOracle {
    function fetchPrice() external returns (uint256);

    function fetchPrice_view() external view returns (uint256);
}