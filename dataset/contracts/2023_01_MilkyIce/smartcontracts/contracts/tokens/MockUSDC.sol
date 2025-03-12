// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';

/// @title Mock USDC ERC20 mintable token for testing purposes
contract MockUSDC is ERC20, ERC20Burnable, AccessControl, ERC20Permit {
  /// @dev this role will be given for the staking contract
  bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');

  constructor() ERC20('USD Coin (PoS)', 'USDC') ERC20Permit('USD Coin (PoS)') {
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _grantRole(MINTER_ROLE, _msgSender());
  }

  function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    _mint(to, amount);
  }

  function decimals() public pure override returns (uint8) {
    return 6;
  }
}
