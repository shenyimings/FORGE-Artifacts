// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MockNonStandardRewardToken {
    string public name;
    uint8 public decimals;
    string public symbol;
    uint256 public totalSupply;
    mapping (address => mapping (address => uint)) public allowance;
    mapping(address => uint) public balanceOf;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor() {
        totalSupply = 10000e18;
        balanceOf[msg.sender] = 10000e18;
        name = "Mock NS";
        symbol = "NS";
        decimals = 18;
    }

    function transfer(address dst, uint256 amount) external {
        balanceOf[msg.sender] = balanceOf[msg.sender] - amount;
        balanceOf[dst] = balanceOf[dst] + amount;
        emit Transfer(msg.sender, dst, amount);
    }

    function transferFrom(address src, address dst, uint256 amount) external {
        allowance[src][msg.sender] = allowance[src][msg.sender] - amount;
        balanceOf[src] = balanceOf[src] - amount;
        balanceOf[dst] = balanceOf[dst] + amount;
        emit Transfer(src, dst, amount);
    }

    function approve(address _spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][_spender] = amount;
        emit Approval(msg.sender, _spender, amount);
        return true;
    }
}
