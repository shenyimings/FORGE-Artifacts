// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../_base/BaseTest.sol";
import "../_mock/MockTokenVault.sol";
import "../_mock/MockGovLPVault.sol";
import "../../../../contracts/v0.8.16/Controller.sol";

/// @title An abstraction of the Controller Testing contract, containing a scaffolding method for creating the fixture
abstract contract ControllerBaseTest is BaseTest {
  MockTokenVault internal mockTokenVaultImpl;
  MockGovLPVault internal mockGovLPVaultImpl;
  Controller internal controller;

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    mockTokenVaultImpl = new MockTokenVault();
    mockGovLPVaultImpl = new MockGovLPVault();
    controller = _setupController();
  }

  function _setupController() internal returns (Controller) {
    Controller _controller = new Controller();

    return _controller;
  }

  receive() external payable {}
}
