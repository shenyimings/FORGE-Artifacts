// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategy {

    event Reward(uint256 amount);
    event PortfolioManagerUpdated(address value);

    event Stake(uint256 amount);
    event Unstake(uint256 amount, uint256 amountReceived);

    event BalanceHealthFactor(uint256 healthFactor);
    event SetHealthFactor(uint256 healthFactor);

    function stake(
        address _asset, // USDC
        uint256 _amount // value for staking in USDC
    ) external;

    function unstake(
        address _asset, // USDC
        uint256 _amount, // minimum expected value for unstaking in USDC
        address _beneficiary, // PortfolioManager
        bool targetIsZero // allow unstake full value
    ) external returns (uint256); // Real unstake value

    function netAssetValue() external view returns (uint256); // Return value in USDC - denominator 6

    function liquidationValue() external view returns (uint256); // Return value in USDC - denominator 6

    function claimRewards(address _to) external returns (uint256); // Return received amount in USDC - denominator 6

    function healthFactorBalance() external; // Balancing aave health factor

    function setHealthFactor(uint256 healthFactor) external; // Aave healthFactor setter
}
