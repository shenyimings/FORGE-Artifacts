// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./LinearFeeModelBase.t.sol";

contract LinearFeeModel_TestGetFeeRate is LinearFeeModelBaseTest {
  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WithZeroBaseRate_WhenStartBlockAtZero() external {
    // Since start block is zero, no multiplier fee returned
    uint256 feeRate = linearFeeModel.getFeeRate(0, 1, 2);

    // utilizationRate = 0%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 0 + ( 100 * 0% ) = 0
    assertEq(feeRate, linearFeeModel.baseRate());
    assertEq(feeRate, 0);
  }

  function test_WithZeroBaseRate_WhenStartBlockIsGTZero() external {
    uint256 feeRate = linearFeeModel.getFeeRate(1, 2, 5);

    // utilizationRate = 2-1 / 5-1
    //                 = 0.25
    //                 = 25%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 0 + ( 100 * 25% ) = 25
    assertEq(feeRate, 25 ether);
  }

  function test_WithBaseRateGTZero_WhenStartBlockAtZero() external {
    linearFeeModel = _setupLinearFeeModel(50 ether, 100 ether);
    // Since start block is zero, no multiplier fee returned
    uint256 feeRate = linearFeeModel.getFeeRate(0, 1, 2);

    // utilizationRate = 0%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 50 + ( 100 * 0% ) = 50
    assertEq(feeRate, linearFeeModel.baseRate());
    assertEq(feeRate, 50 ether);
  }

  function test_WithBaseRateGTZero_WhenStartBlockAtNoneZero() external {
    linearFeeModel = _setupLinearFeeModel(50 ether, 100 ether);
    uint256 feeRate = linearFeeModel.getFeeRate(1, 2, 5);

    // utilizationRate = 2-1 / 5-1
    //                 = 0.25
    //                 = 25%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 50 + ( 100 * 25% ) = 75
    assertEq(feeRate, 75 ether);
  }

  function test_WithFuzzyBaseRate_WithFuzzyMultiplierRate_WhenCurrentBlockLTStartBlock(
    uint256 _baseRate,
    uint256 _multiplierRate
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);

    linearFeeModel = _setupLinearFeeModel(_baseRate, _multiplierRate);
    uint256 feeRate = linearFeeModel.getFeeRate(3, 1, 5);
    assertEq(feeRate, _baseRate);
  }

  function test_WithFuzzyBaseRate_WithFuzzyMultiplierRate_WhenCurrentBlockLTEndBlock(
    uint256 _baseRate,
    uint256 _multiplierRate
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);

    linearFeeModel = _setupLinearFeeModel(_baseRate, _multiplierRate);
    uint256 feeRate = linearFeeModel.getFeeRate(1, 2, 5);

    assertEq(feeRate, _baseRate + ((_multiplierRate * 25) / 100));
  }

  function test_WithFuzzyBaseRateAndFuzzyMultiplierRate_WhenCurrentBlockEQStartBlock(
    uint256 _baseRate,
    uint256 _multiplierRate
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);

    linearFeeModel = _setupLinearFeeModel(_baseRate, _multiplierRate);
    uint256 feeRate = linearFeeModel.getFeeRate(1, 1, 5);
    assertEq(feeRate, _baseRate + (_multiplierRate * 0));
  }

  function test_WithFuzzyBaseRateAndFuzzyMultiplierRate_WhenCurrentBlockEQEndBlock(
    uint256 _baseRate,
    uint256 _multiplierRate
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);

    linearFeeModel = _setupLinearFeeModel(_baseRate, _multiplierRate);
    uint256 feeRate = linearFeeModel.getFeeRate(1, 5, 5);

    assertEq(feeRate, _baseRate + _multiplierRate);
  }

  function test_WithFuzzyBaseRateAndFuzzyMultiplierRate_WhenCurrentBlockGTEndBlock(
    uint256 _baseRate,
    uint256 _multiplierRate
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);

    linearFeeModel = _setupLinearFeeModel(_baseRate, _multiplierRate);
    uint256 feeRate = linearFeeModel.getFeeRate(1, 6, 5);

    assertEq(feeRate, _baseRate);
  }
}
