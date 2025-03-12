pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract ChocoToken is ERC20("Choco Swap", "Choco") {
    constructor(address market, address dev, address team, address partner, address other) public {
        _mint(market, 2100000 ether);
        _mint(dev, 2100000 ether);
        _mint(team, 2100000 ether);
        _mint(partner, 630000 ether);
        _mint(other, 14070000 ether);
    }
}