// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
interface IMasterChef {
  function NFT (  ) external view returns ( address );
  function WETH (  ) external view returns ( address );
  function addKeeper ( address[] memory _keepers ) external;
  function deposit ( uint256[] memory tokenIds ) external;
  function distributePeriod (  ) external view returns ( uint256 );
  function harvest (  ) external;
  function isKeeper ( address ) external view returns ( bool );
  function lastDistributedTime (  ) external view returns ( uint256 );
  function owner (  ) external view returns ( address );
  function pendingReward ( address _user ) external view returns ( uint256 pending );
  function poolInfo (  ) external view returns ( uint256 accRewardPerShare, uint256 lastRewardTime );
  function removeKeeper ( address[] memory _keepers ) external;
  function renounceOwnership (  ) external;
  function rewardPerSecond (  ) external view returns ( uint256 );
  function setDistributionRate ( uint256 amount ) external;
  function setRewardPerSecond ( uint256 _rewardPerSecond ) external;
  function stakedTokenIds ( address _user ) external view returns ( uint256[] memory tokenIds );
  function tokenOwner ( uint256 ) external view returns ( address );
  function transferOwnership ( address newOwner ) external;
  function userInfo ( address ) external view returns ( uint256 amount, int256 rewardDebt );
  function withdraw ( uint256[] memory tokenIds ) external;
}
