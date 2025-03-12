// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ISorbettiere {

  function add(uint16 _allocPoint, address _stakingToken, bool _withUpdate) external;
  function changeEndTime (uint32 addSeconds) external;
  function claimOwnership () external;
  function deposit (uint256 _pid, uint256 _amount) external;
  function emergencyWithdraw (uint256 _pid) external;
  function endTime () external view returns (uint32);
  function getMultiplier(uint256 _from, uint256 _to) external view returns (uint256 );
  function ice () external view returns (address);
  function icePerSecond () external view returns (uint256);
  function massUpdatePools () external;
  function owner () external view returns (address);
  function pendingIce (uint256 _pid, address _user) external view returns (uint256);
  function pendingOwner () external view returns (address);
  function poolInfo (uint256) external view returns (address stakingToken, uint256 stakingTokenTotalAmount, uint256 accIcePerShare, uint32 lastRewardTime, uint16 allocPoint);
  function poolLength () external view returns (uint256);
  function set (uint256 _pid, uint16 _allocPoint, bool _withUpdate) external;
  function setIcePerSecond (uint256 _icePerSecond, bool _withUpdate) external;
  function startTime () external view returns (uint32);
  function totalAllocPoint () external view returns (uint256);
  function transferOwnership (address newOwner, bool direct, bool renounce) external;
  function updatePool (uint256 _pid) external;
  function userInfo (uint256, address) external view returns (uint256 amount, uint256 rewardDebt, uint256 remainingIceTokenReward);
  function withdraw (uint256 _pid, uint256 _amount) external;
}

