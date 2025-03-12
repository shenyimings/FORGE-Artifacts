interface IStake {
  function stakeFor(uint256 amount, address forAddress) external;
  function withdraw(uint256 amount) external;
  function getReward() external;
  function rewardsToken() external view returns(address);
  function earnedByShare(uint256 share) external view returns (uint256);
}
