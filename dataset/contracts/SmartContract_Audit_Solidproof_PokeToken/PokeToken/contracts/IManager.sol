// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IManager {
    function battlefields(address _address) external view returns (bool);

    function trainingfields(address _address) external view returns (bool);

    function evolvers(address _address) external view returns (bool);

    function markets(address _address) external view returns (bool);

    function farmOwners(address _address) external view returns (bool);

    function timesBattle(uint256 level) external view returns (uint256);

    function timeLimitBattle() external view returns (uint256);

    function generation() external view returns (uint256);

    function priceEgg() external view returns (uint256);

    function feeChangeTribe() external view returns (uint256);

    function feeEvolve() external view returns (uint256);

    function feeUpgradeGeneration() external view returns (uint256);

    function feeAddress() external view returns (address);

    function rateBattleReward() external view returns (uint256);
    function rateBattleExp() external view returns (uint256);
    function rateBattleLoseRate() external view returns (uint256);

    function feeMarketRate() external view returns (uint256);

}