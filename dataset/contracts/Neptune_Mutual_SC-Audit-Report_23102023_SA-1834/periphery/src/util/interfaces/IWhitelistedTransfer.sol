// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "../../util/interfaces/IThrowable.sol";

interface IWhitelistedTransfer is IThrowable {
  event TransferWhitelistUpdated(address indexed updatedBy, address[] accounts, bool[] statuses);

  error NoAccountSpecifiedError();
  error TransferRestrictedError();
}
