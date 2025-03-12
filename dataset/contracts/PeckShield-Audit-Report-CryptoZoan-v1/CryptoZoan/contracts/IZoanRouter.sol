// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;

interface IZoanRouter {
    function usersLock(address _user) external view returns (bool);

    function battlefields(address _address) external view returns (bool);

    function evolvers(address _address) external view returns (bool);

    function markets(address _address) external view returns (bool);

    function tokensLock(uint256 _tokenId) external view returns (bool);

    function timesBattle(uint256 level) external view returns (uint256);

    function timeLimitBattle() external view returns (uint256);

    function generation() external view returns (uint256);

    function xBattle() external view returns (uint256);

    function priceEgg() external view returns (uint256);

    function divPercent() external view returns (uint256);

    function feeUpgradeGeneration() external view returns (uint256);

    function feeChangeTribe() external view returns (uint256);

    function feeMarketRate() external view returns (uint256);

    function loseRate() external view returns (uint256);

    function feeEvolve() external view returns (uint256);

    function feeAddress() external view returns (address);

    function zoonToken() external view returns (address);

    function zoanToken() external view returns (address);

    function rewardToken() external view returns (address);
}
