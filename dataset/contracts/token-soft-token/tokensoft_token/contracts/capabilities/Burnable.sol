pragma solidity 0.6.12;

import "../@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "../roles/BurnerRole.sol";

contract Burnable is ERC20, BurnerRole {
  event Burn(address indexed burner, address indexed from, uint256 amount);

  function _burn(address burner, address from, uint256 amount) internal returns (bool) {
      ERC20._burn(from, amount);
      emit Burn(burner, from, amount);
      return true;
  }

  /**
  Allow Burners to burn tokens from valid addresses
  */
  function burn(address account, uint256 amount) public onlyBurner returns (bool) {
      return _burn(msg.sender, account, amount);
  }
}