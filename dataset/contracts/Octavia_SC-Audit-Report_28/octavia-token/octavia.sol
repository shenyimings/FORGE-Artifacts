//           ▄▄
//           ▀██▄    ██        ╔══
//   ▄▄▄▄▄▄▄▄  ▀██▄  ██        ║
//   ▀▀▀▀▀▀▀▀    ▀▀  ██           Octavia
//      ▄▄           ██   ▄▄      by Octavia Laboratories
//    ▄██▀              ▄██▀ 
//  ▄██▀              ▄██▀        The Superhuman AI Assistant
//  ▀▀  ▄▄            ▀▀          
//      ██                        octavia.one
//      ██   ▄▄   ████████        discord.gg/octavia
//      ██   ▀██▄              ║
//      ▀▀     ▀██▄            ╚══
//               ▀▀

pragma solidity ^0.8.9;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Octavia is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("Octavia", "VIA") ERC20Permit("Octavia") {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    // The following functions are overrides required by Solidity.

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
