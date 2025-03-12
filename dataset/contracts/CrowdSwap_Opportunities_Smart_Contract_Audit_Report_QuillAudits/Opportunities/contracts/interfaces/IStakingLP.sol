// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface IStakingLP {

    function stakeLP(uint256 _amount, address _account) external;
    function withdrawRewards(uint256 _lpRewards, address _receiverAccount) external returns (uint256);
    function withdraw(uint256 _lpAmount, address _originAccount) external returns (uint256, uint256);

}
