pragma solidity 0.6.11;


interface IMultiRewards {

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function notifyRewardAmount(address _rewardsToken, uint256 reward) external;

}
