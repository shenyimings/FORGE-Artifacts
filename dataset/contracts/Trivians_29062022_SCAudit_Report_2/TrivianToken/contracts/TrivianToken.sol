// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Trivian Token has 3 decimal digits
uint8 constant numDecimals = 3;

// Trivian Token conforms to the ERC20Burnable specification
contract TrivianToken is ERC20, ERC20Burnable, Pausable, Ownable {
    
    // All tokens are minted by the constructor 
    // and transferred to the multi-sig owner wallet
    constructor() ERC20("Trivian Token", "TRIVIA") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
    
    // Trivian Token can be paused
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return numDecimals;
    }
}
