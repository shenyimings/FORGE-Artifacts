// SPDX-License-Identifier: MIT
pragma abicoder v2;
pragma solidity 0.7.6;

interface IStakePoolCreator {
    function version() external returns (uint);

    function create() external returns (address);
    function initialize(address poolAddress, address pair, address rewardToken, address timelock, address stakePoolRewardFund, bytes calldata data) external;
}