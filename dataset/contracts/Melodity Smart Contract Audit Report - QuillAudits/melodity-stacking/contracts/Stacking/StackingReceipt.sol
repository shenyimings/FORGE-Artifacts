// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/**
	@author Emanuele (ebalo) Balsamo
	
	Stacking receipt contract developed to be easily instantiable with
	custom data.

	Most functions are reserved to the owner as this reduces the possibility
	to lock funds in stacking pools. 
	User can always transfer funds actually being able to use any aggregator,
	or yield optimizer.
 */
contract StackingReceipt is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    constructor(string memory _name, string memory _ticker)
        ERC20(_name, _ticker)
        ERC20Permit(_name)
    {}

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) public override onlyOwner {
        _burn(msg.sender, _amount);
    }

    function burnFrom(address _account, uint256 _amount)
        public
        override
        onlyOwner
    {
        ERC20Burnable.burnFrom(_account, _amount);
    }
}