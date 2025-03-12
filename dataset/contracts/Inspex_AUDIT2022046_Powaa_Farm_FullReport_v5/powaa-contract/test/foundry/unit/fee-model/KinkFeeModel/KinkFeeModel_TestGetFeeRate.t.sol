// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./KinkFeeModelBase.t.sol";

contract KinkFeeModel_TestGetFeeRate is KinkFeeModelBaseTest {
  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WithZeroBaseRate_WhenStartBlockAtZero() external {
    // Since start block is zero, no multiplier fee returned
    uint256 feeRate = kinkFeeModel.getFeeRate(0, 1, 2);

    // utilizationRate = 0%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 0 + ( ( 100 / 100 ) * 0% ) = 0
    assertEq(feeRate, kinkFeeModel.baseRate());
  }

  function test_WithZeroBaseRate_WhenStartBlockIsGTZero() external {
    uint256 feeRate = kinkFeeModel.getFeeRate(1, 2, 5);

    // utilizationRate = 2-1 / 5-1
    //                 = 0.25
    //                 = 25%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 0 + ( ( 100 / 100 ) * 25% ) = 0.25
    assertEq(feeRate, 0.25 ether);
  }

  function test_WithZeroBaseRate_WhenStartBlockIsGTZero_WhenUseingJumpRate()
    external
  {
    kinkFeeModel = _setupKinkFeeModel(0 ether, 100 ether, 100 ether, 0.1 ether);

    uint256 feeRate = kinkFeeModel.getFeeRate(1, 2, 5);

    // utilizationRate = 2-1 / 5-1
    //                 = 0.25
    //                 = 25%
    // normalRate = baseRate + ( multiplierRate * kink )
    //            = 0 + ( ( 100 / 0.1 ) * 0.1 ) = 100
    // excessUtil = utilizationRate - kink
    //            = 25% - 0.1 = 0.15
    // feeRate = ( excessUtil * jumpRate ) + normalRate
    //         = ( 0.15 * 100 ) + 100 = 115
    assertEq(feeRate, 115 ether);
  }

  function test_WithBaseRateGTZero_WhenStartBlockAtZero() external {
    kinkFeeModel = _setupKinkFeeModel(
      50 ether,
      100 ether,
      100 ether,
      100 ether
    );
    // Since start block is zero, no multiplier fee returned
    uint256 feeRate = kinkFeeModel.getFeeRate(0, 1, 2);

    // utilizationRate = 0%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 50 + ( ( 100 / 100 ) * 0% ) = 50
    assertEq(feeRate, kinkFeeModel.baseRate());
  }

  function test_WithBaseRateGTZero_WhenStartBlockAtNoneZero() external {
    kinkFeeModel = _setupKinkFeeModel(
      50 ether,
      100 ether,
      100 ether,
      100 ether
    );
    uint256 feeRate = kinkFeeModel.getFeeRate(1, 2, 5);

    // utilizationRate = 2-1 / 5-1
    //                 = 0.25
    //                 = 25%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 50 + ( ( 100 / 100 ) * 25% ) = 50.25
    assertEq(feeRate, 50.25 ether);
  }

  function test_WithBaseRateGTZero_WhenStartBlockAtNoneZero_WhenUseingJumpRate()
    external
  {
    kinkFeeModel = _setupKinkFeeModel(
      50 ether,
      100 ether,
      100 ether,
      0.1 ether
    );
    uint256 feeRate = kinkFeeModel.getFeeRate(1, 2, 5);

    // utilizationRate = 2-1 / 5-1
    //                 = 0.25
    //                 = 25%
    // normalRate = baseRate + ( multiplierRate * kink )
    //            = 50 + ( ( 100 / 0.1 ) * 0.1 ) = 150
    // excessUtil = utilizationRate - kink
    //            = 25% - 0.1 = 0.15
    // feeRate = ( excessUtil * jumpRate ) + normalRate
    //         = ( 0.15 * 100 ) + 150 = 165
    assertEq(feeRate, 165 ether);
  }

  function test_WithFuzzyBaseRate_WithFuzzyMultiplierRate_WhenCurrentBlockLTStartBlock(
    uint256 _baseRate,
    uint256 _multiplierRate,
    uint256 _jumpRate,
    uint256 _kink
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);
    _jumpRate = bound(_jumpRate, 1e12, 1000000e18);
    _kink = bound(_kink, 1e12, 1000000e18);

    kinkFeeModel = _setupKinkFeeModel(
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );
    uint256 feeRate = kinkFeeModel.getFeeRate(3, 1, 5);

    uint256 expectFeeRate = _getFeeRate(
      3,
      1,
      5,
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );
    assertEq(feeRate, expectFeeRate);
  }

  function test_WithFuzzyBaseRate_WithFuzzyMultiplierRate_WhenCurrentBlockLTEndBlock(
    uint256 _baseRate,
    uint256 _multiplierRate,
    uint256 _jumpRate,
    uint256 _kink
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);
    _jumpRate = bound(_jumpRate, 1e12, 1000000e18);
    _kink = bound(_kink, 1e12, 1000000e18);

    kinkFeeModel = _setupKinkFeeModel(
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );
    uint256 feeRate = kinkFeeModel.getFeeRate(1, 2, 5);

    uint256 expectFeeRate = _getFeeRate(
      1,
      2,
      5,
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );

    assertEq(feeRate, expectFeeRate);
  }

  function test_WithFuzzyBaseRateAndFuzzyMultiplierRate_WhenCurrentBlockEQStartBlock(
    uint256 _baseRate,
    uint256 _multiplierRate,
    uint256 _jumpRate,
    uint256 _kink
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);
    _jumpRate = bound(_jumpRate, 1e12, 1000000e18);
    _kink = bound(_kink, 1e12, 1000000e18);

    kinkFeeModel = _setupKinkFeeModel(
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );
    uint256 feeRate = kinkFeeModel.getFeeRate(1, 1, 5);

    uint256 expectFeeRate = _getFeeRate(
      1,
      1,
      5,
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );
    assertEq(feeRate, expectFeeRate);
  }

  function test_WithFuzzyBaseRateAndFuzzyMultiplierRate_WhenCurrentBlockEQEndBlock(
    uint256 _baseRate,
    uint256 _multiplierRate,
    uint256 _jumpRate,
    uint256 _kink
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);
    _jumpRate = bound(_jumpRate, 1e12, 1000000e18);
    _kink = bound(_kink, 1e12, 1000000e18);

    kinkFeeModel = _setupKinkFeeModel(
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );
    uint256 feeRate = kinkFeeModel.getFeeRate(1, 5, 5);

    uint256 expectFeeRate = _getFeeRate(
      1,
      5,
      5,
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );
    assertEq(feeRate, expectFeeRate);
  }

  function test_WithFuzzyBaseRateAndFuzzyMultiplierRate_WhenCurrentBlockGTEndBlock(
    uint256 _baseRate,
    uint256 _multiplierRate,
    uint256 _jumpRate,
    uint256 _kink
  ) external {
    _baseRate = bound(_baseRate, 1e12, 1000000e18);
    _multiplierRate = bound(_multiplierRate, 1e12, 1000000e18);
    _jumpRate = bound(_jumpRate, 1e12, 1000000e18);
    _kink = bound(_kink, 1e12, 1000000e18);

    kinkFeeModel = _setupKinkFeeModel(
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );
    uint256 feeRate = kinkFeeModel.getFeeRate(1, 6, 5);

    uint256 expectFeeRate = _getFeeRate(
      1,
      6,
      5,
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );
    assertEq(feeRate, expectFeeRate);
  }
}
