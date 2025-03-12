// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
import "../../util/interfaces/IThrowable.sol";

pragma solidity ^0.8.12;

interface IWithPausability is IThrowable {
  event PausersSet(address indexed addedBy, address[] accounts, bool[] statuses);

  error NoPauserSpecifiedError();
}
