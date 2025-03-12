// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../../../external/interfaces/curve/IDepositZap.sol";

interface IConvexSharedMetapoolStrategy {
  function depositZap () external returns (IDepositZap);
}
