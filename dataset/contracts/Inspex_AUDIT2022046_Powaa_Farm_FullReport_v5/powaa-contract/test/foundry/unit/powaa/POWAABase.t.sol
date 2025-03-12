// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.14;

import "../_base/BaseTest.sol";
import "../../../../contracts/v0.8.16/POWAA.sol";

/// @title An abstraction of the POWAAToken Testing contract, containing a scaffolding method for creating the fixture
abstract contract POWAABase is BaseTest {
  POWAA internal POWAAToken;
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    POWAAToken = _setupPOWAAToken(100 ether);
  }

  function _setupPOWAAToken(uint256 _maxTotalSupply) internal returns (POWAA) {
    POWAA _POWAAToken = new POWAA(_maxTotalSupply);
    return _POWAAToken;
  }
}
