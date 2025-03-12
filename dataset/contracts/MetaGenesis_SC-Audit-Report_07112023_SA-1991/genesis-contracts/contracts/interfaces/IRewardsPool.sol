// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IRewardsPool {
    function claim(address) external returns (uint256);
}
