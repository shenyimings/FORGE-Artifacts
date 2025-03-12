// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IMasterChefV2 {

    struct PoolInfo {
        uint128 accKdxPerShare;
        uint64 lastRewardBlock;
        uint64 allocPoint;
    }

    function poolInfo(uint256 pid) external view returns (IMasterChefV2.PoolInfo memory);
    function totalAllocPoint() external view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount, address to) external;
    function kdxPerBlock() external view returns (uint256);    
    function pendingKDX(uint256 _pid, address _user) external view returns (uint256);
}