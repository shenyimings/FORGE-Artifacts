// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../lib/InterfaceIds.sol";

contract MockForwarder {

  function registerIncome(
    address[] memory,
    uint[] memory,
    address,
    bool
  ) external {
    // noop
  }

  function distributeAll(address) external {
    // noop
  }

  function distribute(address) external pure {
    // noop
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
    return interfaceId == InterfaceIds.I_FORWARDER;
  }

}
