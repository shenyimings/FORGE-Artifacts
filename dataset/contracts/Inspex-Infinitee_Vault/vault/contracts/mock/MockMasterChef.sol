// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interface/IMasterChef.sol";
import "./MockERC20.sol";

contract MockMasterChef is IMasterChef {

    IERC20 public farm;
    MockERC20 public reward;
    uint256 public pending;

    mapping(uint256 => mapping(address => uint256)) public userInfos;

    constructor(IERC20 _farm, MockERC20 _reward) public {
      farm = _farm;
      reward = _reward;
    }
  
    function deposit(uint256 _pid, uint256 _amount) override external {
        farm.transferFrom(msg.sender, address(this), _amount);
        userInfos[_pid][msg.sender] += _amount;
        
        if (pending > 0) {
            reward.mint(pending);
            reward.transfer(msg.sender, pending);
            pending = 0;
        }
    }

    function withdraw(uint256 _pid, uint256 _amount) override external {
        userInfos[_pid][msg.sender] -= _amount;
        farm.transfer(msg.sender, _amount);
        
        if (pending > 0) {
            reward.mint(pending);
            reward.transfer(msg.sender, pending);
            pending = 0;
        }
    }

    function pendingCake(uint256, address) override external view returns (uint256) {
        return pending;
    }

    function userInfo(uint256 _pid, address _user) override external view returns (uint256, uint256) {
        return (userInfos[_pid][_user], 0);
    }

    function emergencyWithdraw(uint256 _pid) override external {
        
    }

    function setPending(uint256 _pending) external {
        pending = _pending;
    }

}