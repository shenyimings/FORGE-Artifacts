// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;

interface InterfaceManager {
    function evolvers(address _address) external view returns (bool);

    function markets(address _address) external view returns (bool);

    function farmOwners(address _address) external view returns (bool);

    function heroOwners(address _address) external view returns (bool);

    function dragonOwners(address _address) external view returns (bool);

    function timesBattle(uint256 level) external view returns (uint256);

    function timeLimitBattle() external view returns (uint256);

    function PVPBattle() external view returns (uint256);

    function PVEBattle() external view returns (uint256);

    function priceEgg() external view returns (uint256);

    function divPercent() external view returns (uint256);

    function feeMarket() external view returns (uint256);

    function feeSpawn() external view returns (uint256);

    function feeAddress() external view returns (address);

    function upgradeEquipment() external view returns (uint256);

    function upgradeDragon() external view returns (uint256);

    function hatchEgg() external view returns (uint256);

}