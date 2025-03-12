pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor(uint256 _amount) ERC20("Token", "TKN") {
        _mint(msg.sender, _amount);
    }
}
