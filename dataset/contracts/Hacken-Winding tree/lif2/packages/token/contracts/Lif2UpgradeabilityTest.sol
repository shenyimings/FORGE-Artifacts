// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./Lif2Test.sol";

contract Lif2UpgradeabilityTest is Lif2Test {

  function newFunction() public pure returns(bool) {
    return true;
  }
}
