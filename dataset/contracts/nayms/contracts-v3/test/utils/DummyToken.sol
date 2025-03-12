// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { IERC20 } from "src/erc20/IERC20.sol";

contract DummyToken is IERC20 {
    string public name = "Dummy";
    string public symbol = "DUM";
    uint8 public decimals = 18;
    uint256 public totalSupply = 0;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function transfer(address to, uint256 value) external returns (bool) {
        if (value == 0) {
            return false;
        }

        require(balanceOf[msg.sender] >= value, "not enough balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        if (value == 0) {
            revert();
        }

        require(allowance[from][msg.sender] >= value, "not enough allowance");
        require(balanceOf[from] >= value, "not enough balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        return true;
    }

    function mint(address to, uint256 value) external {
        balanceOf[to] += value;
        totalSupply += value;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {}
}
