// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract GetLinksToken is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    uint256 private _cap = 250000000 ether;

    constructor() ERC20("GetLinks", "LINKS") ERC20Permit("GetLinks") {
        _mint(msg.sender, 250000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function _mint(address account, uint256 amount) internal override {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20: cap exceeded");
        super._mint(account, amount);
    }

}