// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import './extensions/ERC20Capped.sol';


contract DeFiToken is AccessControl, ERC20Capped, ERC20Permit, ERC20Votes, ERC20Burnable {
  bytes32 public constant MINER_ROLE = keccak256('MINER_ROLE');
  bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');

  /// @notice Minimum mining delay.
  uint32 public constant MINIMUM_DELAY_MINING = 547 days;

  /// @notice Minimum time between mining.
  uint32 public constant MINIMUM_TIME_BETWEEN_MINING = 90 days;

  /// @notice Cap on the percentage(4%) of totalSupply that can be mined at each mine.
  uint8 public constant MINE_CAP = 4;

  /// @notice The timestamp after which mine may occur.
  uint256 public mineAllowedAfter;

  event Mine(uint256 value);

  error MineTimeErr();
  error MineAmountErr();

  constructor() 
    ERC20('DeFi', 'DEFI')
    ERC20Permit('DeFi')
    ERC20Capped(1000000000 * 10 ** decimals())
  {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());
    _setupRole(MINER_ROLE, _msgSender());

    mineAllowedAfter = block.timestamp + MINIMUM_DELAY_MINING;
  }

  function mint(address to_, uint256 amount_)
    external
    onlyRole(MINTER_ROLE)
  {
    _mint(to_, amount_);
  }

  function mine(uint256 amount_)
    external
    onlyRole(MINER_ROLE)
  {
    if (block.timestamp < mineAllowedAfter) revert MineTimeErr();
    if (amount_ > (cap() * MINE_CAP / 100)) revert MineAmountErr();
    
    mineAllowedAfter = block.timestamp + MINIMUM_TIME_BETWEEN_MINING;
    _setCap(cap() + amount_);
    emit Mine(amount_);
  }

  function _afterTokenTransfer(address from_, address to_, uint256 amount_)
    internal
    override(ERC20, ERC20Votes)
  {
    super._afterTokenTransfer(from_, to_, amount_);
  }

  function _mint(address to_, uint256 amount_)
    internal
    override(ERC20, ERC20Capped, ERC20Votes)
  {
    super._mint(to_, amount_);
  }

  function _burn(address account_, uint256 amount_)
    internal
    override(ERC20, ERC20Votes)
  {
    super._burn(account_, amount_);
  }
}
