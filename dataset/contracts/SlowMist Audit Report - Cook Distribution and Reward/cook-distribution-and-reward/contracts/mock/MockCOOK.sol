pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockCOOK is ERC20 {
    constructor(uint256 initialSupply) public ERC20("COOK Protocol", "COOK") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address account, uint256 amount) public returns (bool) {
        _mint(account, amount);
        return true;
    }
}
