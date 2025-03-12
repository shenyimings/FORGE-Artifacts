// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { IYieldSource } from "../interfaces/IYieldSource.sol";
import { IRewardTracker } from "../interfaces/gmx/IRewardTracker.sol";

contract StakedGLPYieldSource is IYieldSource {
    using SafeERC20 for IERC20;

    IERC20 public immutable override generatorToken;
    IERC20 public immutable override yieldToken;
    IRewardTracker public immutable tracker;
    uint256 public deposits;
    address public owner;

    constructor(address stglp_, address weth_, address tracker_) {
        require(stglp_ != address(0), "SGYS: zero address stglp");
        require(weth_ != address(0), "SGYS: zero address weth");
        require(tracker_ != address(0), "SGYS: zero address tracker");

        owner = msg.sender;
        generatorToken = IERC20(stglp_);
        yieldToken = IERC20(weth_);
        tracker = IRewardTracker(tracker_);
    }

    function setOwner(address owner_) external override {
        require(msg.sender == owner, "only owner");
        owner = owner_;
    }

    function deposit(uint256 amount, bool claim) external override {
        require(msg.sender == owner, "only owner");
        generatorToken.safeTransferFrom(msg.sender, address(this), amount);

        if (claim) _harvest();
    }

    function withdraw(uint256 amount, bool claim, address to) external override {
        require(msg.sender == owner, "only owner");

        uint256 balance = generatorToken.balanceOf(address(this));
        if (amount > balance) {
            amount = balance;
        }
        generatorToken.safeTransfer(to, amount);

        if (claim) _harvest();
    }

    function _amountPending() internal view returns (uint256) {
        return tracker.claimable(address(this));
    }

    function _harvest() internal {
        uint256 before = yieldToken.balanceOf(address(this));
        tracker.claim(address(this));
        uint256 amount = yieldToken.balanceOf(address(this)) - before;
        yieldToken.safeTransfer(owner, amount);
    }

    function harvest() external override {
        require(msg.sender == owner, "only owner");
        _harvest();
    }

    function amountPending() external override view returns (uint256) {
        return _amountPending();
    }

    function amountGenerator() external override view returns (uint256) {
        return generatorToken.balanceOf(address(this));
    }
}
