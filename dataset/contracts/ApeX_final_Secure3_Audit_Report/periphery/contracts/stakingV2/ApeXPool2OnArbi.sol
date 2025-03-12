// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IApeXPool2.sol";
import "../utils/Ownable.sol";
import "../libraries/TransferHelper.sol";

contract ApeXPool2OnArbi is Ownable {
    event PausedStateChanged(bool newState);
    event Staked(address indexed token, address indexed user, uint256 accountId, uint256 amount);
    event Unstaked(address indexed token, address indexed user, address indexed to, uint256 accountId, uint256 amount);

    address public immutable apeX;
    bool public paused;
    mapping(address => mapping(uint256 => uint256)) public stakingAPEX;

    constructor(address _apeX, address _owner) {
        apeX = _apeX;
        owner = _owner;
    }

    function setPaused(bool newState) external onlyOwner {
        require(paused != newState, "same state");
        paused = newState;
        emit PausedStateChanged(newState);
    }

    function stakeAPEX(uint256 accountId, uint256 amount) external {
        require(!paused, "paused");
        TransferHelper.safeTransferFrom(apeX, msg.sender, address(this), amount);
        stakingAPEX[msg.sender][accountId] += amount;
        emit Staked(apeX, msg.sender, accountId, amount);
    }

    function unstakeAPEX(address to, uint256 accountId, uint256 amount) external {
        require(amount <= stakingAPEX[msg.sender][accountId], "not enough balance");
        stakingAPEX[msg.sender][accountId] -= amount;
        TransferHelper.safeTransfer(apeX, to, amount);
        emit Unstaked(apeX, msg.sender, to, accountId, amount);
    }
}
