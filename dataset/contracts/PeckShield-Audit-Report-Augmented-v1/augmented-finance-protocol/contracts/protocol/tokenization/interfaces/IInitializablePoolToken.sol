// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {ILendingPool} from '../../../interfaces/ILendingPool.sol';
import {IBalanceHook} from '../../../interfaces/IBalanceHook.sol';
import {PoolTokenConfig} from './PoolTokenConfig.sol';

/**
 * @title IInitializablePoolToken
 * @notice Interface for the initialize function on PoolToken or DeptToken
 **/
interface IInitializablePoolToken {
  /**
   * @dev Emitted when a token is initialized
   * @param underlyingAsset The address of the underlying asset
   * @param pool The address of the associated lending pool
   * @param treasury The address of the treasury
   * @param aTokenName the name of the aToken
   * @param aTokenSymbol the symbol of the aToken
   * @param aTokenDecimals the decimals of the underlying
   * @param params A set of encoded parameters for additional initialization
   **/
  event Initialized(
    address indexed underlyingAsset,
    address indexed pool,
    address treasury,
    string aTokenName,
    string aTokenSymbol,
    uint8 aTokenDecimals,
    bytes params
  );

  /**
   * @dev Initializes the aToken
   * @param config The data about lending pool where this token will be used
   * @param aTokenName The name of the aToken
   * @param aTokenSymbol The symbol of the aToken
   * @param aTokenDecimals The decimals of the aToken, same as the underlying asset's
   */
  function initialize(
    PoolTokenConfig calldata config,
    string calldata aTokenName,
    string calldata aTokenSymbol,
    uint8 aTokenDecimals,
    bytes calldata params
  ) external;
}
