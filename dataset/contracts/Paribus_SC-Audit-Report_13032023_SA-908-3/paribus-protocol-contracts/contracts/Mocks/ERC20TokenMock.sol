// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20TokenMock is Ownable, ERC20Burnable {
    constructor(uint256 initialSupply, string memory _name, string memory _symbol) public ERC20(_name, _symbol) {
        _mint(owner(), initialSupply);
    }

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        ERC20._mint(_to, _amount);
        return true;
    }
}
