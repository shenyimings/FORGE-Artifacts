// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IStakedAvax {
    function getPooledAvaxByShares(uint256 _shares) external view returns (uint256);
}
