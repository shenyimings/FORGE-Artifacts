// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {VersionedInitializable} from '../../tools/upgradeability/VersionedInitializable.sol';
import {UserConfiguration} from '../libraries/configuration/UserConfiguration.sol';
import {ReserveConfiguration} from '../libraries/configuration/ReserveConfiguration.sol';
import {ReserveLogic} from '../libraries/logic/ReserveLogic.sol';
import {IMarketAccessController} from '../../access/interfaces/IMarketAccessController.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';

abstract contract LendingPoolStorage {
  using ReserveLogic for DataTypes.ReserveData;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;

  IMarketAccessController internal _addressesProvider;
  address internal _collateralManager;

  mapping(address => DataTypes.ReserveData) internal _reserves;
  mapping(address => DataTypes.UserConfigurationMap) internal _usersConfig;

  // the list of the available reserves, structured as a mapping for gas savings reasons
  mapping(uint256 => address) internal _reservesList;

  uint16 internal _maxStableRateBorrowSizePct;

  uint16 internal _flashLoanPremiumPct;

  uint16 internal constant FEATURE_FLASHLOAN = 1 << 0;
  uint16 internal constant FEATURE_LIQUIDATION = 1 << 1;
  uint16 internal _disabledFeatures;

  uint8 internal _reservesCount;

  uint8 internal constant _maxNumberOfReserves = 128;

  uint8 internal _nestedFlashLoanCalls;

  bool internal _paused;
}
