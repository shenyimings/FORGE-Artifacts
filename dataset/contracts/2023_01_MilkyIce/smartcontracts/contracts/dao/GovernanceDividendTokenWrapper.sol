// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '../tokens/NonTransferableToken.sol';
import '../tokens/interfaces/IMintableBurnableToken.sol';

/**
 * @notice This contract represents dividend tokens that have been staked by users in the staking contract.
 * @dev This contract is used to track the amount of staked tokens for each user and is managed by
 * MultiERC20WeightedLocker contract which can mint and burn governance tokens when users stake or unstake.
 * This governance token is also non-transferable as stakes cannot be transferred.
 */
contract GovernanceDividendTokenWrapper is
  IMintableBurnableToken,
  ERC20Permit,
  ERC20Votes,
  NonTransferableToken,
  Ownable
{
  constructor(
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) ERC20Permit(_name) {}

  /**
   * @dev This function gives a certain user voting power when they stake. This function can only be called by
   * the MultiERC20WeightedLocker contract.
   */
  function mint(address to, uint256 amount) public override onlyOwner {
    _mint(to, amount);
    _delegate(to, to);
  }

  /**
   * @dev This function removes a certain user voting power when they unstake. This function can only be called by
   *  the MultiERC20WeightedLocker contract.
   */
  function burn(address from, uint256 amount) public override onlyOwner {
    _burn(from, amount);
  }

  // The following functions are overrides required by Solidity.

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20, NonTransferableToken) {
    super._beforeTokenTransfer(from, to, amount);
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20, ERC20Votes) {
    super._afterTokenTransfer(from, to, amount);
  }

  function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
    super._mint(to, amount);
  }

  function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
    super._burn(account, amount);
  }
}
