// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';

/**
 * @notice This is a reward token that is given to the stakers. It can be
 * minted by the staking contract.
 */
contract MintableToken is ERC20, ERC20Burnable, AccessControl, ERC20Permit {
  /// @dev this role will be given to the staking contract
  bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');

  constructor(
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) ERC20Permit(_name) {
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    _mint(to, amount);
  }
}
