// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

error NonTransferableToken__TransferIsNotAllowed();

/**
 * @dev Mixin to make a token non-transferable. This is used for governance and staked tokens
 * that are not transferable.
 */
abstract contract NonTransferableToken is ERC20 {
  /// @dev This function is called when a user tries to transfer tokens.
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    // if it isn't a mint or burn then revert
    if (from != address(0) && to != address(0)) {
      revert NonTransferableToken__TransferIsNotAllowed();
    }

    super._beforeTokenTransfer(from, to, amount);
  }
}
