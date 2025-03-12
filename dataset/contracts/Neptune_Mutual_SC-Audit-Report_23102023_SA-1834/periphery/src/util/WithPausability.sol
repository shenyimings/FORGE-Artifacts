// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interfaces/IWithPausability.sol";

abstract contract WithPausability is IWithPausability, PausableUpgradeable {
  function _setPausers(mapping(address => bool) storage _pausers, address[] calldata accounts, bool[] calldata statuses) internal {
    if (accounts.length == 0) {
      revert NoPauserSpecifiedError();
    }

    if (accounts.length != statuses.length) {
      revert RelatedArrayItemCountMismatchError();
    }

    for (uint256 i = 0; i < accounts.length; i++) {
      _pausers[accounts[i]] = statuses[i];
    }

    emit PausersSet(_msgSender(), accounts, statuses);
  }
}
