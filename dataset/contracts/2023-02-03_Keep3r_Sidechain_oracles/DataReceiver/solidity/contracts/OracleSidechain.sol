//SPDX-License-Identifier: MIT
/*

Coded for The Keep3r Network with ♥ by

██████╗░███████╗███████╗██╗░░░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░
██╔══██╗██╔════╝██╔════╝██║░░░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗
██║░░██║█████╗░░█████╗░░██║░░░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║
██║░░██║██╔══╝░░██╔══╝░░██║░░░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║
██████╔╝███████╗██║░░░░░██║░░░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝
╚═════╝░╚══════╝╚═╝░░░░░╚═╝░░░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

https://defi.sucks

*/

pragma solidity >=0.8.8 <0.9.0;

import {IOracleSidechain, IOracleFactory} from '../interfaces/IOracleSidechain.sol';
import {Oracle} from '@uniswap/v3-core/contracts/libraries/Oracle.sol';
import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';

/// @title The SidechainOracle contract
/// @notice Computes and stores on-chain price data from Mainnet
contract OracleSidechain is IOracleSidechain {
  using Oracle for Oracle.Observation[65535];

  /// @inheritdoc IOracleSidechain
  IOracleFactory public immutable factory;

  struct Slot0 {
    // the current price
    uint160 sqrtPriceX96;
    // the current tick
    int24 tick;
    // the most-recently updated index of the observations array
    uint16 observationIndex;
    // the current maximum number of observations that are being stored
    uint16 observationCardinality;
    // the next maximum number of observations to store, triggered in observations.write
    uint16 observationCardinalityNext;
    // the current protocol fee as a percentage of the swap fee taken on withdrawal
    // represented as an integer denominator (1/x)%
    uint8 feeProtocol;
    // whether the pool is locked
    bool unlocked;
  }
  /// @inheritdoc IOracleSidechain
  Slot0 public slot0;

  /// @inheritdoc IOracleSidechain
  Oracle.Observation[65535] public observations;

  /// @inheritdoc IOracleSidechain
  bytes32 public immutable poolSalt;

  uint24 public poolNonce;
  /// @inheritdoc IOracleSidechain
  address public token0;
  /// @inheritdoc IOracleSidechain
  address public token1;
  /// @inheritdoc IOracleSidechain
  uint24 public fee;

  /// @dev Returns the block timestamp truncated to 32 bits, i.e. mod 2**32. This method is overridden in tests.
  function _getBlockTimestamp() internal view virtual returns (uint32) {
    return uint32(block.timestamp); // truncation is desired
  }

  constructor() {
    factory = IOracleFactory(msg.sender);
    uint16 _cardinality;
    (poolSalt, poolNonce, _cardinality) = factory.oracleParameters();

    slot0 = Slot0({
      sqrtPriceX96: 0,
      tick: 0,
      observationIndex: _cardinality - 1,
      observationCardinality: _cardinality,
      observationCardinalityNext: _cardinality,
      feeProtocol: 0,
      unlocked: true
    });
  }

  /// @inheritdoc IOracleSidechain
  function initializePoolInfo(
    address _tokenA,
    address _tokenB,
    uint24 _fee
  ) external {
    if (!slot0.unlocked) revert AI();

    (address _token0, address _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    if (poolSalt != keccak256(abi.encode(_token0, _token1, _fee))) revert InvalidPool();

    token0 = _token0;
    token1 = _token1;
    fee = _fee;
    slot0.unlocked = false;

    emit PoolInfoInitialized(poolSalt, _token0, _token1, _fee);
  }

  /// @inheritdoc IOracleSidechain
  function observe(uint32[] calldata _secondsAgos)
    external
    view
    returns (int56[] memory _tickCumulatives, uint160[] memory _secondsPerLiquidityCumulativeX128s)
  {
    return observations.observe(_getBlockTimestamp(), _secondsAgos, slot0.tick, slot0.observationIndex, 0, slot0.observationCardinality);
  }

  /// @inheritdoc IOracleSidechain
  function write(ObservationData[] memory _observationsData, uint24 _poolNonce) external onlyDataReceiver returns (bool _written) {
    if (_poolNonce != poolNonce++) return false;

    uint256 _observationsDataLength = _observationsData.length;
    for (uint256 _i; _i < _observationsDataLength; ) {
      _write(_observationsData[_i]);
      unchecked {
        ++_i;
      }
    }
    slot0.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(slot0.tick);

    // emits UniV3 Swap event topic with minimal data
    emit Swap(address(0), address(0), 0, 0, slot0.sqrtPriceX96, 0, slot0.tick);
    return true;
  }

  function increaseObservationCardinalityNext(uint16 _observationCardinalityNext) external onlyFactory {
    uint16 _observationCardinalityNextOld = slot0.observationCardinalityNext;
    if (_observationCardinalityNext <= _observationCardinalityNextOld) revert AI();
    slot0.observationCardinalityNext = _observationCardinalityNext;
    emit IncreaseObservationCardinalityNext(_observationCardinalityNextOld, _observationCardinalityNext);
  }

  function _write(ObservationData memory _observationData) private {
    (uint16 _indexUpdated, uint16 _cardinalityUpdated) = observations.write(
      slot0.observationIndex,
      _observationData.blockTimestamp,
      slot0.tick,
      0,
      slot0.observationCardinality,
      slot0.observationCardinalityNext
    );
    (slot0.observationIndex, slot0.observationCardinality) = (_indexUpdated, _cardinalityUpdated);
    slot0.tick = _observationData.tick;
  }

  modifier onlyDataReceiver() {
    if (msg.sender != address(factory.dataReceiver())) revert OnlyDataReceiver();
    _;
  }

  modifier onlyFactory() {
    if (msg.sender != address(factory)) revert OnlyFactory();
    _;
  }
}
