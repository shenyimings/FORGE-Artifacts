// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../interfaces/IUniPool.sol";
import "./MockToken.sol";

/**
 * @title Mock reward contract.
 */
contract MockReward is IUniPool {
    address public token;
    address[] public rewards;
    mapping(address => uint256) public amounts;

    constructor(address _token, address[] memory _rewards) {
        token = _token;
        rewards = _rewards;
    }

    function setAmount(address _token, uint256 _amount) public {
        amounts[_token] = _amount;
    }

    function stake(uint256 _amount) public override {
        MockToken(token).transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) public override {
        MockToken(token).transfer(msg.sender, _amount);
    }

    function exit() public override {
        getReward();
        withdraw(MockToken(token).balanceOf(address(this)));
    }

    function getReward() public override {
        for (uint256 i = 0; i < rewards.length; i++) {
            MockToken(rewards[i]).mint(msg.sender, amounts[rewards[i]]);
        }
    }
}