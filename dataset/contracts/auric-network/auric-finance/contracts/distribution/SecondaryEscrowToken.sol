pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";

contract SecondaryEscrowToken is ERC20, ERC20Detailed, ERC20Burnable, ERC20Mintable {

  constructor() public
  ERC20Detailed("AUSC Escrow LP", "AUSCESC", 18)
  {
  }

}

