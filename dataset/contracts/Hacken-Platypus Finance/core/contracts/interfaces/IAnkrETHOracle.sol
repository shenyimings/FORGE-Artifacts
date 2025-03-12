// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IAnkrETHOracle {
    function getRatioFor(address ankrETHToken) external view returns (uint256);
}
