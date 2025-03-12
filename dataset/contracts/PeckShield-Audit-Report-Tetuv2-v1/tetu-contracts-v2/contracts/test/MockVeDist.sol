// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proxy/ControllableV3.sol";

contract MockVeDist {

  function checkpoint() external {
    // noop
  }

  function checkpointTotalSupply() external {
    // noop
  }

}
