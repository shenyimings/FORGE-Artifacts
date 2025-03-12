// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/**
           +-+-+-+-+-+              
           |A|T|g|o|v|              
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |A|n|i|m|a|l| |&| |A|n|i|m|a|l|T|V|
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |G|o|v|e|r|n|a|n|c|e| |T|o|k|e|n|  
 +-+-+-+-+-+-+-+-+-+-+ +-+-+-+-+-+  

 * @title ATgovToken

 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract ATgovToken is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("ATgovToken", "ATgov") ERC20Permit("ATgovToken") {
    
_mint(msg.sender, 1000000e18); //1,000,000 tokens totalsupply
}
    // The functions below are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
