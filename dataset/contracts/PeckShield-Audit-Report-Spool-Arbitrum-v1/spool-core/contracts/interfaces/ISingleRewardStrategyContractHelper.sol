// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

interface ISingleRewardStrategyContractHelper {

    function claimReward(bool executeClaim) external returns(uint256, bool);

    function deposit(uint256) external;

    function withdraw(uint256) external;

    function withdrawAll() external;
}
