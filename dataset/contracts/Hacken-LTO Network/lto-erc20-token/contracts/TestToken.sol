pragma solidity ^0.4.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol';
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";

contract TestToken is ERC20, ERC20Mintable, ERC20Burnable {
}
