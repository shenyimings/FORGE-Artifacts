// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/console.sol";

library PureLog {
  function _cast(function(string memory) internal view fnIn)
    internal
    pure
    returns (function(string memory) internal pure fnOut)
  {
    assembly {
      fnOut := fnIn
    }
  }

  function _log(string memory errorMessage) internal view {
    console.log(errorMessage);
  }

  function log(string memory errorMessage) internal pure {
    _cast(_log)(errorMessage);
  }
}
