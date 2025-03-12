// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../_base/BaseTest.sol";

import "../../../../../contracts/v0.8.16/fee-model/KinkFeeModel.sol";

import "../../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/// @title An abstraction of the KinkFeeModel Testing contract, containing a scaffolding method for creating the fixture
abstract contract KinkFeeModelBaseTest is BaseTest {
  using FixedPointMathLib for uint256;

  KinkFeeModel internal kinkFeeModel;

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    kinkFeeModel = _setupKinkFeeModel(0, 100 ether, 100 ether, 100 ether);
  }

  function _setupKinkFeeModel(
    uint256 _baseRate,
    uint256 _multiplierRate,
    uint256 _jumpRate,
    uint256 _kink
  ) internal returns (KinkFeeModel) {
    KinkFeeModel _kinkFeeModel = new KinkFeeModel(
      _baseRate,
      _multiplierRate,
      _jumpRate,
      _kink
    );

    return _kinkFeeModel;
  }

  function _utilizationRate(
    uint256 _startBlock,
    uint256 _currentBlock,
    uint256 _endBlock
  ) internal pure returns (uint256) {
    if (
      _startBlock == 0 ||
      _currentBlock < _startBlock ||
      _currentBlock > _endBlock
    ) {
      return 0;
    }

    uint256 passedBlock = _currentBlock - _startBlock;

    return passedBlock.divWadDown(_endBlock - _startBlock);
  }

  function _getFeeRate(
    uint256 _startBlock,
    uint256 _currentBlock,
    uint256 _endBlock,
    uint256 _baseRate,
    uint256 _multiplierRate,
    uint256 _jumpRate,
    uint256 _kink
  ) internal pure returns (uint256) {
    _multiplierRate = _multiplierRate.divWadDown(_kink);
    uint256 ur = _utilizationRate(_startBlock, _currentBlock, _endBlock);

    if (ur < _kink) {
      return ur.mulWadDown(_multiplierRate) + _baseRate;
    }

    uint256 normalRate = _kink.mulWadDown(_multiplierRate) + _baseRate;
    uint256 excessUtil = ur - _kink;

    return excessUtil.mulWadDown(_jumpRate) + normalRate;
  }
}
