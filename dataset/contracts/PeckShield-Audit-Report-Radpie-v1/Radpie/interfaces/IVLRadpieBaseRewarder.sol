// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IBaseRewardPool.sol";

interface IVLRadpieBaseRewarder is IBaseRewardPool {
    
    function rewardTokenInfos() external view
        returns (
            address[] memory bonusTokenAddresses,
            string[] memory bonusTokenSymbols
        );
    
    function allEarned(address _account) external view
        returns (uint256[] memory pendingBonusRewards);

    function getReward(
        address _account,
        address _receiver
    ) external returns (bool);

    function queueRadpie(uint256 _amount, address _user, address _receiver) external returns(bool);
}