// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../interfaces/IERC20Decimals.sol";
import "./IPoolAdapter.sol";

interface IYearnVault {
    function deposit(uint256 amount) external returns (uint256);

    // If amount is not specified, withdraws all
    function withdraw() external returns (uint256);

    function withdraw(uint256 maxShares) external returns (uint256);

    // Returns underlying token address
    function token() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function pricePerShare() external view returns (uint256);
}

contract YearnPoolAdapter is IPoolAdapter {
    function deposit(
        address pool,
        uint256 amount,
        bytes memory /* args */
    ) external {
        IYearnVault(pool).deposit(amount);
    }

    function stakingBalance(
        address pool,
        bytes memory /* args */
    ) external view returns (uint256) {
        uint256 pricePerShare = IYearnVault(pool).pricePerShare();

        address token = IYearnVault(pool).token();
        uint8 tokenDecimals = IERC20Decimals(token).decimals();

        uint256 sharesAmount = IYearnVault(pool).balanceOf(address(this));
        return (sharesAmount * pricePerShare) / 10**tokenDecimals;
    }

    function rewardBalance(
        address, /* pool */
        bytes memory /* args */
    ) external pure returns (uint256) {
        return 0;
    }

    function withdraw(
        address pool,
        uint256 amount,
        bytes memory /* args */
    ) external {
        uint256 pricePerShare = IYearnVault(pool).pricePerShare();

        address token = IYearnVault(pool).token();
        uint8 tokenDecimals = IERC20Decimals(token).decimals();
        uint256 sharesAmount = (amount * 10**tokenDecimals) / pricePerShare;

        IYearnVault(pool).withdraw(sharesAmount);
    }

    function withdrawAll(
        address pool,
        bytes memory /* args */
    ) external {
        IYearnVault(pool).withdraw();
    }

    function stakedToken(
        address pool,
        bytes memory /* args */
    ) external view returns (address) {
        return IYearnVault(pool).token();
    }

    function rewardToken(
        address pool,
        bytes memory /* args */
    ) external view returns (address) {
        return IYearnVault(pool).token();
    }
}
