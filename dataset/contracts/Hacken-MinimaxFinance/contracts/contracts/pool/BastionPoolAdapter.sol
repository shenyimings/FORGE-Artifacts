// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./IPoolAdapter.sol";

interface IBastionPool is IERC20Upgradeable {
    function mint(uint mintAmount) external;

    function redeem(uint redeemAmount) external;

    function redeemUnderlying(uint redeemAmount) external;

    function underlying() external view returns (address);

    function balanceOfUnderlying(address owner) external returns (uint);
}

contract BastionPoolAdapter is IPoolAdapter {
    function stakingBalance(address pool, bytes memory) external returns (uint256) {
        return IBastionPool(pool).balanceOfUnderlying(address(this));
    }

    function rewardBalance(address, bytes memory) external pure returns (uint256) {
        return 0;
    }

    function deposit(
        address pool,
        uint256 amount,
        bytes memory /* args */
    ) external {
        IERC20Upgradeable staked = IERC20Upgradeable(IBastionPool(pool).underlying());
        staked.approve(pool, amount);
        IBastionPool(pool).mint(amount);
    }

    function withdraw(
        address pool,
        uint256 amount,
        bytes memory /* args */
    ) external {
        IBastionPool(pool).redeemUnderlying(amount);
    }

    function withdrawAll(
        address pool,
        bytes memory /* args */
    ) external {
        IBastionPool(pool).redeem(IERC20Upgradeable(pool).balanceOf(address(this)));
    }

    function stakedToken(
        address pool,
        bytes memory /* args */
    ) public view returns (address) {
        return IBastionPool(pool).underlying();
    }

    function rewardToken(
        address pool,
        bytes memory /* args */
    ) public view returns (address) {
        return IBastionPool(pool).underlying();
    }
}
