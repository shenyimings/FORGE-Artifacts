pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract TestToken is ERC20, ERC20Detailed, ERC20Capped {

  constructor() public
  ERC20Detailed("AUSC LP UNI V2", "UNI-V2", 18)
  ERC20Capped(1000000000 * 1e18)
  {}

}

