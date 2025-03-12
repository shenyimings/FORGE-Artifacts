// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
    uint256 boostMultiplier;
}

interface IPancakeMasterChefV2 {
    function lpToken(uint256 index) external returns (IERC20);

    function poolLength() external view returns (uint256 pools);

    function userInfo(uint256 poolId, address user)
        external
        view
        returns (UserInfo memory);

    function deposit(uint256 pid, uint256 amount) external;

    function withdraw(uint256 pid, uint256 amount) external;
}
