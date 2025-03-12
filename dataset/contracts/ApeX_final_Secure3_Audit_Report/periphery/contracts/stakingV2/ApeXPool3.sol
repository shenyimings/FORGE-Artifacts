// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IApeXPool3.sol";
import "../utils/Ownable.sol";
import "../libraries/TransferHelper.sol";

contract ApeXPool3 is IApeXPool3, Ownable {
    address public override apeX;
    address public override esApeX;

    struct stakingInfo{
        address lockToken;
        address owner;
        uint256 accountId;
        uint256 amount;
        uint256 lockPeriod;
        uint256 lockStart;
        bool unlocked;
    }

    mapping(uint256 => stakingInfo) public stakingAPEX;
    mapping(uint256 => stakingInfo) public stakingEsAPEX;

    uint256 public globalStakeId;
    bool public override paused;

    constructor(address _apeX, address _esApeX, address _owner) {
        apeX = _apeX;
        esApeX = _esApeX;
        owner = _owner;
    }

    function setPaused(bool newState) external override onlyOwner {
        require(paused != newState, "same state");
        paused = newState;
        emit PausedStateChanged(newState);
    }

    function setApex(address _newApex) external override onlyOwner {
        require(_newApex != address(0));
        apeX = _newApex;
        emit ApexChanged(_newApex);
    }

    function setEsApex(address _newEsApex) external override onlyOwner {
        require(_newEsApex != address(0));
        esApeX = _newEsApex;
        emit EsApexChanged(_newEsApex);
    }

    function stakeAPEX(uint256 accountId, uint256 amount,uint256 lockPeriod) external override {
        require(!paused, "paused");
        require(apeX != address(0));
        TransferHelper.safeTransferFrom(apeX, msg.sender, address(this), amount);

        globalStakeId++;
        stakingAPEX[globalStakeId] = stakingInfo({
            lockToken: apeX,
            owner: msg.sender,
            accountId: accountId,
            amount: amount,
            lockPeriod: lockPeriod,
            lockStart: block.timestamp,
            unlocked: false
        });

        emit Staked(apeX, msg.sender, globalStakeId, accountId, amount,lockPeriod);
    }

    function stakeEsAPEX(uint256 accountId, uint256 amount,uint256 lockPeriod) external override {
        require(!paused, "paused");
        require(esApeX != address(0));
        TransferHelper.safeTransferFrom(esApeX, msg.sender, address(this), amount);
       
        globalStakeId++;
        stakingEsAPEX[globalStakeId] = stakingInfo({
            lockToken: esApeX,
            owner: msg.sender,
            accountId: accountId,
            amount: amount,
            lockPeriod: lockPeriod,
            lockStart: block.timestamp,
            unlocked: false
        });

        emit Staked(esApeX, msg.sender, globalStakeId, accountId, amount,lockPeriod);
    }

    function unstakeAPEX(uint256 stakeId) external override {
       _unstakeAPEX(stakeId);
    }

    function _unstakeAPEX(uint256 stakeId) private {
        stakingInfo memory info = stakingAPEX[stakeId];
        require(info.owner == msg.sender, "not allowed");
        require(info.lockStart+info.lockPeriod <= block.timestamp,"in lock period");
        require(info.lockToken == apeX, "apeX token mismatch");
        require(!info.unlocked,"already unlocked");

        TransferHelper.safeTransfer(apeX, info.owner, info.amount);
        stakingAPEX[stakeId].unlocked = true;
        emit Unstaked(stakeId);
    }

    function batchUnstakeAPEX(uint256[] calldata stakeIds) external  {
        for (uint i = 0; i < stakeIds.length; i++) {
            _unstakeAPEX(stakeIds[i]);
        }
    }

    function _unstakeEsAPEX(uint256 stakeId) private{
        stakingInfo memory info = stakingEsAPEX[stakeId];
        require(info.owner == msg.sender, "not allowed");
        require(info.lockStart+info.lockPeriod <= block.timestamp,"in lock period");
        require(info.lockToken == esApeX, "esApeX token mismatch");
        require(!info.unlocked,"already unlocked");

        TransferHelper.safeTransfer(esApeX, info.owner, info.amount);
        stakingEsAPEX[stakeId].unlocked = true;
        emit Unstaked(stakeId);
    }

    function unstakeEsAPEX(uint256 stakeId) external override {
        _unstakeEsAPEX(stakeId);
    }

    function batchUnstakeEsAPEX(uint256[] calldata stakeIds) external  {
        for (uint i = 0; i < stakeIds.length; i++) {
            _unstakeEsAPEX(stakeIds[i]);
        }
    }
}
