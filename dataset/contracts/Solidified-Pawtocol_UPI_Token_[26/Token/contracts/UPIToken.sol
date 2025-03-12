pragma solidity 0.5.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract UPIToken is ERC20, ERC20Detailed, ERC20Mintable, ERC20Burnable {
  
    string private _name = "Pawtocol Network UPI Token";
    string private _symbol = "UPI";
    uint8 private _decimals = 18;
    uint256 private INITIAL_SUPPLY = uint(1000000000) * (uint256(10) ** _decimals);
    
    constructor() 
    	ERC20Detailed(_name, _symbol, _decimals) 
    	public
    {
    	mint(msg.sender, INITIAL_SUPPLY);
        renounceMinter();
    }

    function () external {
        revert("Invalid request.");
    }
    
}
