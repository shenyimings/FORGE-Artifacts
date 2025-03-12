pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC20/ERC20Detailed.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC20/ERC20Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC20/ERC20Capped.sol";

contract Token is ERC20Detailed,ERC20Capped, ERC20Pausable{

    constructor () public ERC20Detailed("Vanywhere New Token", "VANY", 18) ERC20Capped(800000000000000000000000000) {
         _mint(msg.sender, 800000000 * (10 ** uint256(decimals())));
    }
}