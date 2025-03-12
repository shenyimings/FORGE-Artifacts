// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proxy/ControllableV3.sol";

contract MockGauge is ControllableV3 {

  function init(address controller_) external initializer {
    __Controllable_init(controller_);
  }

  function handleBalanceChange(address) external {
    // noop
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_GAUGE || super.supportsInterface(interfaceId);
  }

}
