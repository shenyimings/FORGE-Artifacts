// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IBooster {

    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool depositToPlatypus,
        uint256 deadline
    ) external;

    function multiClaim(
        uint256[] memory _pids,
        address _account
    ) external;

    function withdraw(
        uint256 _pid,
        uint256 _amount,
        bool _claim,
        uint256 minOut
    ) external;

}


interface IRewardPool {
    function balanceOf(address _account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getReward() external returns (bool);

    function getReward(address, bool) external returns (bool);

    function stake(address _account, uint256 _amount) external returns (bool);

    function migrateStake(address _account, uint256 _amount)
    external
    returns (bool);

    function unStake(
        address _account,
        uint256 _amount,
        bool _claim
    ) external returns (bool);

    function queueNewRewards(uint256 _rewards) external returns (bool);

    function addExtraReward(address _reward) external returns (bool);

    function initialize(
        uint256 _pid,
        address rewardToken_,
        address operator_,
        address rewardManager_,
        address governance_
    ) external;

    function clearExtraRewards() external;
}
