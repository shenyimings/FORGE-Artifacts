// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Avive is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
  constructor(
    address initialOwner_,
    uint256 initialSupply_,
    string memory name_,
    string memory symbol_
  ) ERC20(name_, symbol_) Ownable(initialOwner_) {
    _mint(initialOwner_, initialSupply_);
  }

  /**
   * @dev pause only by owner if necessary
   */
  function pause() public onlyOwner {
    _pause();
  }

  /**
   * @dev unPause only by owner if necessary
   */
  function unpause() public onlyOwner {
    _unpause();
  }

  // The following functions are overrides required by Solidity.

  /**
   * @dev Required by Solidity.
   * @param from address
   * @param to address
   * @param value uint256
   */
  function _update(
    address from,
    address to,
    uint256 value
  ) internal override(ERC20, ERC20Pausable) {
    super._update(from, to, value);
  }
}
