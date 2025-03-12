// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IERC20} from '../../dependencies/openzeppelin/contracts/IERC20.sol';
import {SafeERC20} from '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import {WadRayMath} from '../../tools/math/WadRayMath.sol';
import {VersionedInitializable} from '../../tools/upgradeability/VersionedInitializable.sol';
import {PoolTokenConfig} from './interfaces/PoolTokenConfig.sol';
import {DepositTokenBase} from './base/DepositTokenBase.sol';

/**
 * @title Augmented Finance ERC20 deposit token (agToken)
 * @dev Implementation of the interest bearing token for the Augmented Finance protocol
 */
contract DepositToken is DepositTokenBase, VersionedInitializable {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  uint256 private constant TOKEN_REVISION = 0x1;

  function getRevision() internal pure virtual override returns (uint256) {
    return TOKEN_REVISION;
  }

  /**
   * @dev Initializes the aToken
   * @param config The data about lending pool where this token will be used
   * @param name The name of the aToken
   * @param symbol The symbol of the aToken
   * @param decimals The decimals of the aToken, same as the underlying asset's
   */
  function initialize(
    PoolTokenConfig calldata config,
    string calldata name,
    string calldata symbol,
    uint8 decimals,
    bytes calldata params
  ) external override initializerRunAlways(TOKEN_REVISION) {
    _initializeERC20(name, symbol, decimals);
    if (!isRevisionInitialized(TOKEN_REVISION)) {
      _initializeDomainSeparator();
    }
    _treasury = config.treasury;
    _initializePoolToken(config, name, symbol, decimals, params);
  }
}
