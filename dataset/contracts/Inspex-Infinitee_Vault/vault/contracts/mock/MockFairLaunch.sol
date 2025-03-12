// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interface/IFairLaunch.sol";
import "./MockERC20.sol";

contract MockFairLaunch is IFairLaunch {

    IERC20 public farm;
    MockERC20 public reward;
    uint256 public pending;

    mapping(uint256 => mapping(address => uint256)) public userInfos;

    constructor(IERC20 _farm, MockERC20 _reward) public {
      farm = _farm;
      reward = _reward;
    }
  
    function deposit(address _for, uint256 _pid, uint256 _amount) external override {
        farm.transferFrom(_for, address(this), _amount);
        userInfos[_pid][_for] += _amount;
        
        if (pending > 0) {
            reward.mint(pending);
            reward.transfer(_for, pending);
            pending = 0;
        }
    }

    function withdraw(address _for, uint256 _pid, uint256 _amount) public override {
        userInfos[_pid][_for] -= _amount;
        farm.transfer(_for, _amount);
        
        if (pending > 0) {
            reward.mint(pending);
            reward.transfer(_for, pending);
            pending = 0;
        }
    }

    function withdrawAll(address _for, uint256 _pid) external override {
        withdraw(_for, _pid, userInfos[_pid][_for]);
    }

    function pendingAlpaca(uint256, address) external view override returns (uint256) {
        return pending;
    }

    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256) {
        return (userInfos[_pid][_user], 0);
    }

    function harvest(uint256) external override {
        if (pending > 0 ) {
          reward.mint(pending);
          reward.transfer(msg.sender, pending);
          pending = 0;
        }
    }

    function setPending(uint256 _pending) external {
        pending = _pending;
    }
    
    function emergencyWithdraw(uint256 _pid) external override {}

}