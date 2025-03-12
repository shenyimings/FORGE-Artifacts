// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IApeXPool3 {
    event PausedStateChanged(bool newState);
    event Staked(address indexed token, address indexed user, uint256 stakeId, uint256 accountId, uint256 amount, uint256 lockPeriod);
    event Unstaked(uint256 stakeId);

    function apeX() external view returns (address);

    function esApeX() external view returns (address);

    function paused() external view returns (bool);

    function setPaused(bool newState) external;

    function stakeAPEX(uint256 accountId, uint256 amount,uint256 lockPeriod) external;

    function stakeEsAPEX(uint256 accountId, uint256 amount,uint256 lockPeriod) external;

    function unstakeAPEX(uint256 stakeId) external;

    function unstakeEsAPEX(uint256 stakeId) external;
}
