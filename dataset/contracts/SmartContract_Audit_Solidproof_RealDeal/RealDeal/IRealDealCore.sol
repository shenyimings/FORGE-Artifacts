pragma solidity ^0.8.6;

// SPDX-License-Identifier: MIT
interface IRealDealCore {
    /**
     * @dev Triggers TPTS.
     * Only used by the master RealDeal contract.
     */
    function tptsUpdateTraderPerformance(address trader, int256 netTradeProfit, uint256 competitionIndex) external;
    
    /**
     * @dev Returns the number of reward amounts in total for all reward classes.
     */
    function getRewardCount(uint256 targetCompetitionIndex) external view returns(uint256);
    
    /**
     * @dev Initiates ARAM.
     * Only used by the master RealDeal contract.
     */
    function aramStart(uint256 targetCompetitionIndex) external returns(bool);
    
    /**
     * @dev Triggers the ARAM reward airdrop for one batch of winners. 
     * Only used by the master RealDeal contract.
     */
    function aramTrigger(uint256 targetCompetitionIndex) external;
    
    /**
     * @dev Emergency recovery option to recover funds stuck in the buffer pool to recover address.
     * Only used by the master RealDeal contract.
     */
    function aramEmergencyRecovery(address recoveryAddress) external;
    
    /**
     * @dev Sets the reward pool size for ARAM to distribute.
     * Only used by the master RealDeal contract.
     */
    function setRewardPoolSize(uint256 targetCompetitionIndex, uint256 amount) external;
    
    /**
     * @dev Returns the reward pool size of the ARAM.
     */
    function getRewardPoolSize(uint256 targetCompetitionIndex) external view returns(uint256);
    
    /**
     * @dev Returns whether ARAM is active now.
     */
    function isAramInProgress() external view returns(bool);
    
    /**
     * @dev Emergency force stop ARAM.
     * Only used by the master RealDeal contract.
     */
    function aramForceCancel() external;
    
    /**
     * @dev Returns the rank of the trader at the specified competition.
     */
    function getRankOfTrader(address trader, uint256 targetCompetitionIndex) external view returns(uint256);
    
    /**
     * @dev Returns the trader at the specified rank at the specified competition.
     */
    function getTraderAtRank(uint256 rank, uint256 targetCompetitionIndex) external view returns(address);
    
    /**
     * @dev Returns the performance of the specified trader at the specified competition.
     */
    function getPerformanceOfTrader(address trader, uint256 targetCompetitionIndex) external view returns(int256);
    
    /**
     * @dev Returns the performance of the last trader in top winers list.
     */
    function getLastWinnerPerformance(uint256 targetCompetitionIndex) external view returns(int256);
}