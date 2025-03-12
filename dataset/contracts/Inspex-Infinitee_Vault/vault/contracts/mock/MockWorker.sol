// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../mock/MockERC20.sol";
import "../vault/InfiniteeVault.sol";

contract MockWorker is YieldWorker {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public farm;
    MockERC20 public reward;
    InfiniteeVault public workerVault;
    uint256 public pending;

    constructor(address _farmToken, address _rewardToken) public {
        farm = IERC20(_farmToken);
        reward = MockERC20(_rewardToken);
    }

    function farmToken() external view override returns (address) {
        return address(farm);
    }

    function farmRewardToken() external view override returns (address) {
        return address(reward);
    }

    function userRewardToken() external view override returns (address) {
        return address(reward);
    }

    function pendingReward() external view override returns (uint256) {
        return pending;
    }

    function setPending(uint256 _pending) external {
        pending = _pending;
    }

    function setVault(address _vault) external {
        workerVault = InfiniteeVault(_vault);
    }

    function deposit() external override {}

    function withdraw(uint256 _amount) external override {
        farm.transfer(msg.sender, _amount);
    }

    function claimReward(uint256 _amount) external override {
        reward.transfer(msg.sender, _amount);
    }

    function work() external override {
        workerVault.updateVault();
        reward.mint(pending);
        pending = 0;
    }

    function emergencyWithdraw() external override {
    }
}
