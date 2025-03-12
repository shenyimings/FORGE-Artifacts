pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MintableERC20 is ERC20 {
    constructor(string memory name, string memory symbol) public ERC20(name, symbol) {}
    function mint(uint256 value) public returns (bool) {
        _mint(_msgSender(), value);
        return true;
    }
}
