// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol"; // call ERC20 safely
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../Interfaces/IWETH.sol";

contract WrapETH is ERC20, ReentrancyGuard, IWETH {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public constant exchange_rate = 1;

    constructor () public ERC20("Test WETH", "WETH") { 
        _setupDecimals(18);
    }

    receive() payable external {
        deposit();
    }

    function deposit() payable public override nonReentrant {
        uint256 _issue = msg.value.mul(exchange_rate);
        _mint(msg.sender, _issue);
    }

    function withdraw(uint256 amount) external override nonReentrant {
        _burn(msg.sender, amount);
        uint256 _send = amount.div(exchange_rate);
        msg.sender.transfer(_send);
    }
}