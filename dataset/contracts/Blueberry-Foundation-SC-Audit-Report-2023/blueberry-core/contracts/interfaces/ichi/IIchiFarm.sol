// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IIchiFarm {
    function lpToken(uint256 pid) external view returns (address);

    function pendingIchi(
        uint256 pid,
        address user
    ) external view returns (uint256);

    function poolInfo(
        uint256 pid
    )
        external
        view
        returns (
            uint256 accIchiPerShare,
            uint256 lastRewardBlock,
            uint256 allocPoint
        );

    function userInfo(
        uint256 pid,
        address to
    ) external view returns (uint256 amount, int256 rewardDebt);

    function deposit(uint256 pid, uint256 amount, address to) external;

    function withdraw(uint256 pid, uint256 amount, address to) external;

    function harvest(uint256 pid, address to) external;
}
