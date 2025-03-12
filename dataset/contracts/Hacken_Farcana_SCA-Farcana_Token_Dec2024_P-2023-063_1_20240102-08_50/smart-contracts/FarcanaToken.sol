// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract FarcanaToken is ERC20, Ownable2Step {
    event Burn(address indexed burner, uint256 value);

	
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {
        uint256 _decimals = 18;
        uint256 _initialSupply = 5000000000 * 10 ** _decimals;
        _mint(msg.sender, _initialSupply);
    }

  function burn(uint256 _value) external onlyOwner {
        _burn(msg.sender, _value);
        emit Burn(msg.sender, _value);
  }
 
}