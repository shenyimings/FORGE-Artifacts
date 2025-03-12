// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OCTF is ERC20, Ownable {
    using SafeERC20 for IERC20;

    constructor(
        string memory _name, 
        string memory _symbol,
        uint256 _initialSupply
    ) public ERC20(_name, _symbol) {
        _mint(msg.sender, _initialSupply * (10 ** 18) );
    } 

    function clearTokens(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(this), "Cannot clear same tokens as OCTF");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}