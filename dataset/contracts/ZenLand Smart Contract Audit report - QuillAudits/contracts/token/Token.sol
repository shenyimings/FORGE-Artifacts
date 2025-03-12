pragma solidity 0.8.14;

import './ERC20/ERC20.sol';


contract Token is ERC20 {
    constructor(
        string memory _name, string memory _symbol
    ) ERC20(_name, _symbol) {}

    function mint(address to, uint256 value) public {
        require(value > 0, 'Value must greater than 0');
        _mint(to, value);
    }
}