// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../_base/BaseTest.sol";

import "../../../../../contracts/v0.8.16/fee-model/LinearFeeModel.sol";

/// @title An abstraction of the LinearFeeModel Testing contract, containing a scaffolding method for creating the fixture
abstract contract LinearFeeModelBaseTest is BaseTest {
  LinearFeeModel internal linearFeeModel;

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    linearFeeModel = _setupLinearFeeModel(0, 100 ether);
  }

  function _setupLinearFeeModel(uint256 _baseRate, uint256 _multiplierRate)
    internal
    returns (LinearFeeModel)
  {
    LinearFeeModel _linearFeeModel = new LinearFeeModel(
      _baseRate,
      _multiplierRate
    );

    return _linearFeeModel;
  }
}
