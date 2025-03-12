//SPDX-License-Identifier: MIT
pragma solidity >=0.8.8 <0.9.0;

import {Governable} from '@defi-wonderland/solidity-utils/solidity/contracts/Governable.sol';
import {OracleSidechain} from './OracleSidechain.sol';
import {IDataReceiver, IOracleFactory, IOracleSidechain, IBridgeReceiverAdapter} from '../interfaces/IDataReceiver.sol';

/// @title The DataReceiver contract
/// @notice Handles reception of broadcast data and delivers it to correspondant oracle
contract DataReceiver is IDataReceiver, Governable {
  /// @inheritdoc IDataReceiver
  IOracleFactory public immutable oracleFactory;

  /// @inheritdoc IDataReceiver
  mapping(bytes32 => IOracleSidechain) public deployedOracles;

  /// @inheritdoc IDataReceiver
  mapping(IBridgeReceiverAdapter => bool) public whitelistedAdapters;

  constructor(address _governor, IOracleFactory _oracleFactory) Governable(_governor) {
    if (address(_oracleFactory) == address(0)) revert ZeroAddress();
    oracleFactory = _oracleFactory;
  }

  function addObservations(
    IOracleSidechain.ObservationData[] memory _observationsData,
    bytes32 _poolSalt,
    uint24 _poolNonce
  ) external onlyWhitelistedAdapters {
    _addObservations(_observationsData, _poolSalt, _poolNonce);
  }

  function _addObservations(
    IOracleSidechain.ObservationData[] memory _observationsData,
    bytes32 _poolSalt,
    uint24 _poolNonce
  ) internal {
    // Read, store or deploy oracle given poolSalt
    IOracleSidechain _oracle = deployedOracles[_poolSalt];
    if (address(_oracle) == address(0)) {
      _oracle = oracleFactory.getPool(_poolSalt);
      if (address(_oracle) == address(0)) {
        _oracle = oracleFactory.deployOracle(_poolSalt, _poolNonce);
      }
      deployedOracles[_poolSalt] = _oracle;
    }
    // Try to write observations data into oracle
    if (_oracle.write(_observationsData, _poolNonce)) {
      emit ObservationsAdded(_poolSalt, _poolNonce, _observationsData, msg.sender);
    } else {
      revert ObservationsNotWritable();
    }
  }

  function whitelistAdapter(IBridgeReceiverAdapter _receiverAdapter, bool _isWhitelisted) external onlyGovernor {
    _whitelistAdapter(_receiverAdapter, _isWhitelisted);
  }

  /// @inheritdoc IDataReceiver
  function whitelistAdapters(IBridgeReceiverAdapter[] calldata _receiverAdapters, bool[] calldata _isWhitelisted) external onlyGovernor {
    uint256 _receiverAdapterLength = _receiverAdapters.length;
    if (_receiverAdapterLength != _isWhitelisted.length) revert LengthMismatch();
    unchecked {
      for (uint256 _i; _i < _receiverAdapterLength; ++_i) {
        _whitelistAdapter(_receiverAdapters[_i], _isWhitelisted[_i]);
      }
    }
  }

  function _whitelistAdapter(IBridgeReceiverAdapter _receiverAdapter, bool _isWhitelisted) internal {
    whitelistedAdapters[_receiverAdapter] = _isWhitelisted;
    emit AdapterWhitelisted(_receiverAdapter, _isWhitelisted);
  }

  modifier onlyWhitelistedAdapters() {
    if (!whitelistedAdapters[IBridgeReceiverAdapter(msg.sender)]) revert UnallowedAdapter();
    _;
  }
}
