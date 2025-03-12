// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPangolinMiniChef {
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    function userInfo(uint256 pid, address user)
        external
        view
        returns (UserInfo memory);

    function lpToken(uint256 pid) external view returns (address);

    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function harvest(uint256 pid, address to) external;

    function withdraw(
        uint256 pid,
        uint256 amount,
        address to
    ) external;
}
