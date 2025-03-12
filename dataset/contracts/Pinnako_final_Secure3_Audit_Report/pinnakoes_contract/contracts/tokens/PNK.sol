// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PNK is ERC20, Ownable {
    constructor() ERC20("PNK", "PNK") {
        uint256 initialSupply = 88480000 * (10 ** 18);
        _mint(msg.sender, initialSupply);
    }
    
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}