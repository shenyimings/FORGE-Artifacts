//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WHIRL is ERC20Capped, Ownable {
    using SafeMath for uint256;

    constructor(uint256 totalSupply, uint256 initialSupply)
        ERC20("PolyWhirl", "WHIRL")
        ERC20Capped(totalSupply.mul(1e18))
    {
        require(initialSupply <= totalSupply);
        ERC20._mint(msg.sender, initialSupply.mul(1e18));
    }

    function mint(address recipient, uint256 amount) public onlyOwner {
        _mint(recipient, amount);
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }
}
