// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPoolAdapter.sol";

// IPancakeMasterChefPool implementation can be found at
// https://github.com/pancakeswap/pancake-farm/blob/master/contracts/MasterChef.sol
interface IPancakeMasterChefPool {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    function userInfo(uint256, address) external view returns (UserInfo memory);

    function pendingCake(uint256, address) external view returns (uint256);

    function enterStaking(uint256) external;

    function leaveStaking(uint256) external;
}

contract PancakeMasterChefAdapter is IPoolAdapter {
    address private immutable token;

    constructor(address _token) {
        token = _token;
    }

    function deposit(
        address pool,
        uint256 amount,
        bytes memory /* args */
    ) external {
        IPancakeMasterChefPool(pool).enterStaking(amount);
    }

    function stakingBalance(
        address pool,
        bytes memory /* args */
    ) external view returns (uint256) {
        IPancakeMasterChefPool masterPool = IPancakeMasterChefPool(pool);
        return masterPool.userInfo(0, address(this)).amount;
    }

    function rewardBalance(
        address pool,
        bytes memory /* args */
    ) external view returns (uint256) {
        IPancakeMasterChefPool masterPool = IPancakeMasterChefPool(pool);
        return masterPool.pendingCake(0, address(this));
    }

    function withdraw(
        address pool,
        uint256 amount,
        bytes memory /* args */
    ) external {
        IPancakeMasterChefPool(pool).leaveStaking(amount);
    }

    function withdrawAll(
        address pool,
        bytes memory /* args */
    ) external {
        IPancakeMasterChefPool masterPool = IPancakeMasterChefPool(pool);
        uint256 withdrawAmount = masterPool.userInfo(0, address(this)).amount;
        masterPool.leaveStaking(withdrawAmount);
    }

    function stakedToken(
        address, /* pool */
        bytes memory /* args */
    ) external view returns (address) {
        return token;
    }

    function rewardToken(
        address, /* pool */
        bytes memory /* args */
    ) external view returns (address) {
        return token;
    }
}
