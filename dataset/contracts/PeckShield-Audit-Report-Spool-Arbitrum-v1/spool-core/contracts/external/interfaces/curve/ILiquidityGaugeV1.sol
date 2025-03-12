// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ILiquidityGaugeV1 {
    function rewarded_token() external view returns (address);

    function claimable_reward(address user) external view returns (uint256);

    function claimed_rewards_for(address user) external view returns (uint256);

    function claim_rewards(address user) external;

    function balanceOf(address user) external view returns (uint256);

    function withdraw(uint256 lp) external;

    function deposit(uint256 lp, address user) external;
}
