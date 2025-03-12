// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAvatarArtStaking{
    /**
     * @dev Get APR
    */
    function getAnnualProfit(uint nftStageIndex) external view returns(uint);
    
    /**
     * @dev Get total BNU token amount staked in contract
     */ 
    function getTotalStaked() external view returns(uint);
    
    /**
     * @dev Get user's BNU earned
     */ 
    function getUserEarnedAmount(address account) external view returns(uint);
    
    /**
     * @dev Get list of staking users
     */ 
    function getStakingUsers(uint nftStageIndex) external view returns(address[] memory);
    
    /**
     * @dev Get total BNU token amount staked by `account`
     */ 
    function getUserStakedAmount(uint nftStageIndex, address account) external view returns(uint);
    
    /**
     * @dev User join to stake BNU
     */ 
    function stake(uint nftStageIndex, uint amount) external returns(bool);
    
    /**
     * @dev User withdraw staked BNU from contract
     * User will receive all staked BNU and reward BNU based on APY configuration
     */ 
    function withdraw(uint nftStageIndex, uint amount) external returns(bool);
}