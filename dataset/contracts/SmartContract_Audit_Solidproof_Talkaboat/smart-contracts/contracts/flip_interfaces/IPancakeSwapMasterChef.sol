// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.7;

interface IPancakeSwapMasterChef {
    function pendingCake(uint256 _pid, address _user) external view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function enterStaking(uint256 _amount) external;
    function leaveStaking(uint256 _amount) external;
    function withdrawWithoutRewards(uint256 _pid) external;
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);
    function poolInfo(uint256 _pid) external view returns (uint256);
}