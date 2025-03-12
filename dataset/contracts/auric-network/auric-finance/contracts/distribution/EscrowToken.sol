pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract EscrowToken is ERC20, ERC20Detailed, ERC20Burnable {

  constructor() public
  ERC20Detailed("AUSC Escrow LP", "AUSCESC", 18)
  {
    _mint(msg.sender, 30000000 * 1e18);
  }

}

