// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMasterChef {
    function MaxAllocPoint() external view returns (uint256);

    function add(uint256 _allocPoint, address _lpToken) external;

    function boo() external view returns (address);

    function booPerSecond() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function dev(address _devaddr) external;

    function devaddr() external view returns (address);

    function emergencyWithdraw(uint256 _pid) external;

    function getMultiplier(uint256 _from, uint256 _to) external view returns (uint256);

    function massUpdatePools() external;

    function maxBooPerSecond() external view returns (uint256);

    function owner() external view returns (address);

    function pendingBOO(uint256 _pid, address _user) external view returns (uint256);

    function poolInfo(uint256)
        external
        view
        returns (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardTime,
            uint256 accBOOPerShare
        );

    function poolLength() external view returns (uint256);

    function renounceOwnership() external;

    function set(uint256 _pid, uint256 _allocPoint) external;

    function setBooPerSecond(uint256 _booPerSecond) external;

    function startTime() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function updatePool(uint256 _pid) external;

    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);

    function withdraw(uint256 _pid, uint256 _amount) external;
}
