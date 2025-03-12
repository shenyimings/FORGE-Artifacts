// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proxy/ControllableV3.sol";

contract ControllableTest is ControllableV3 {

  function init(address controller_) external initializer {
    ControllableV3.__Controllable_init(controller_);
  }

  function increase() external {
    this.increaseRevision(address(this));
  }
}
