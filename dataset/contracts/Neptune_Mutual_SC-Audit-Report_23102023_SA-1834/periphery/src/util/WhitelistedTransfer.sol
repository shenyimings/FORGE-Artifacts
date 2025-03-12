// solhint-disable
// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "./interfaces/IWhitelistedTransfer.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

abstract contract WhitelistedTransfer is IWhitelistedTransfer, ContextUpgradeable {
  function _updateTransferWhitelist(mapping(address => bool) storage _whitelist, address[] calldata accounts, bool[] memory statuses) internal {
    if (accounts.length == 0) {
      revert NoAccountSpecifiedError();
    }

    if (accounts.length != statuses.length) {
      revert RelatedArrayItemCountMismatchError();
    }

    for (uint256 i = 0; i < accounts.length; i++) {
      _whitelist[accounts[i]] = statuses[i];
    }

    emit TransferWhitelistUpdated(_msgSender(), accounts, statuses);
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                          Validations
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function _throwIfNonWhitelistedTransfer(mapping(address => bool) storage _whitelist, address from, address to, uint256) internal view {
    // Token mints
    if (from == address(0)) {
      // aren't restricted
      return;
    }

    // Token burns
    if (to == address(0)) {
      // aren't restricted either
      return;
    }

    // Someone not whitelisted
    // ............................ can still transfer to a whitelisted address
    if (_whitelist[from] == false && _whitelist[to] == false) {
      // but nowhere else
      revert TransferRestrictedError();
    }
  }
}
