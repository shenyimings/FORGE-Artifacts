// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}
