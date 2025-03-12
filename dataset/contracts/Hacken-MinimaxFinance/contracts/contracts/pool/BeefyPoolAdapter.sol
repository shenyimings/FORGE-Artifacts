// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./IPoolAdapter.sol";

// Interface of https://bscscan.com/address/0x97e5d50Fe0632A95b9cf1853E744E02f7D816677
interface IBeefyPool {
    function deposit(uint256) external;

    function withdraw(uint256 _shares) external;

    function withdrawAll() external;

    // Returns an uint256 with 18 decimals of how much underlying asset one vault share represents.
    function getPricePerFullShare() external view returns (uint256);

    // Staked token address
    function want() external view returns (address);
}

contract BeefyPoolAdapter is IPoolAdapter {
    function deposit(
        address pool,
        uint256 amount,
        bytes memory /* args */
    ) external {
        IBeefyPool(pool).deposit(amount);
    }

    function stakingBalance(
        address pool,
        bytes memory /* args */
    ) external view returns (uint256) {
        uint256 sharesBalance = IERC20Upgradeable(pool).balanceOf(address(this));

        // sharePrice has 18 decimals
        uint256 sharePrice = IBeefyPool(pool).getPricePerFullShare();
        return (sharesBalance * sharePrice) / 1e18;
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
        // sharePrice has 18 decimals
        uint256 sharePrice = IBeefyPool(pool).getPricePerFullShare();
        uint256 sharesAmount = (amount * 1e18) / sharePrice;
        IBeefyPool(pool).withdraw(sharesAmount);
    }

    function withdrawAll(
        address pool,
        bytes memory /* args */
    ) external {
        IBeefyPool(pool).withdrawAll();
    }

    function stakedToken(
        address pool,
        bytes memory /* args */
    ) external view returns (address) {
        return IBeefyPool(pool).want();
    }

    function rewardToken(
        address pool,
        bytes memory /* args */
    ) external view returns (address) {
        return IBeefyPool(pool).want();
    }
}
