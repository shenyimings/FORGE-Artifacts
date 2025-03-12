// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ILiquidityGaugeV3 {
    function rewarded_tokens(uint256 i) external view returns (address);

    function claim_rewards(address user, address receiver) external;

    function balanceOf(address user) external view returns (uint256);

    function withdraw(uint256 lp) external;

    function deposit(uint256 lp, address user) external;
}
