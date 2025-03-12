// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

interface ISupplySchedule {
    // Views
    function mintableSupply() external view returns (uint);

    function isMintable() external view returns (bool);

    // Mutative functions

    function mint() external;

    function setTreasuryDiversion(uint _treasuryDiversion) external;

    function setTradingRewardsDiversion(uint _tradingRewardsDiversion) external;
    
    function setStakingRewards(address _stakingRewards) external;

    function setTradingRewards(address _tradingRewards) external;
}