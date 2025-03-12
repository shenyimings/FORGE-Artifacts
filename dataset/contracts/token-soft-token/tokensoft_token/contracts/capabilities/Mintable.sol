pragma solidity 0.6.12;

import "../@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "../roles/MinterRole.sol";

contract Mintable is ERC20, MinterRole {
  event Mint(address indexed minter, address indexed to, uint256 amount);

  function _mint(address minter, address to, uint256 amount) internal returns (bool) {
      ERC20._mint(to, amount);
      emit Mint(minter, to, amount);
      return true;
  }

  /**
  Allow Owners to mint tokens to valid addresses
  */
  function mint(address account, uint256 amount) public onlyMinter returns (bool) {
      return Mintable._mint(msg.sender, account, amount);
  }
}