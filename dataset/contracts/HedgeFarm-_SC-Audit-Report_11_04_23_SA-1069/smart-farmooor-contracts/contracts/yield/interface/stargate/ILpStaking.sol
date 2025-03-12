// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ILpStaking {

    /**
     * returns amount of claimable STG tokens
     */
    function pendingStargate(uint256 pid, address user) external view returns (uint256);

    /**
     * deposit Lp tokens to earn STG
     * if called with amount == 0 is effectively acts as claim for STG  
     */
    function deposit(uint256 pid, uint256 amount) external;

    /**
     * withdraw Lp tokens and claim STG
     */
    function withdraw(uint256 pid, uint256 amount) external;

    /**
     * return: amount uint256, rewardDebt uint256
     */ 
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256); 

    /**
     * return: lpToken address, allocPoint uint256, lastRewardBlock uint256, accStargatePerShare uint256
     */    
    function poolInfo(uint256 poolId) external view returns(address,  uint256, uint256, uint256);

}