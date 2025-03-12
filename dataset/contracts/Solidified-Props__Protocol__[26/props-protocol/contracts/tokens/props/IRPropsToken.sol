// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

interface IRPropsToken {
    function setPropsAppStaking(address _propsAppStaking) external;

    function setPropsUserStaking(address _propsUserStaking) external;

    function distributeRewards(
        uint256 _amount,
        uint256 _appRewardsPercentage,
        uint256 _userRewardsPercentage
    ) external;

    function withdrawRewards(uint256 _appRewardsAmount, uint256 _userRewardsAmount) external;

    function changeDailyAppRewardEmission(uint256 _appDailyRewardEmission) external;

    function changeDailyUserRewardEmission(uint256 _userDailyRewardEmission) external;

    function swap(address account) external;
}
