// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "../../gauge-pool/interfaces/ILiquidityGaugePool.sol";

interface IGaugeControllerRegistry {
  struct Gauge {
    bytes32 key;
    uint256 emission;
  }

  event LiquidityGaugePoolAdded(bytes32 key, ILiquidityGaugePool pool);
  event LiquidityGaugePoolUpdated(bytes32 key, ILiquidityGaugePool previous, ILiquidityGaugePool current);
  event GaugeSet(uint256 indexed epoch, bytes32 indexed key, ILiquidityGaugePool pool, uint256 distribution);
  event GaugeAllocationTransferred(uint256 indexed epoch, uint256 totalAllocation);
  event GaugeControllerRegistryPoolDeactivated(address indexed sender, bytes32 indexed key);
  event GaugeControllerRegistryPoolActivated(address indexed sender, bytes32 indexed key);
  event GaugeControllerRegistryPoolDeleted(address indexed sender, bytes32 key);

  error InvalidGaugeEpochError();
  error PoolNotFoundError(bytes32 key);
  error PoolNotActiveError(bytes32 key);
  error PoolDeactivatedError(bytes32 key);
  error PoolAlreadyDeactivatedError(bytes32 key);
  error PoolNotDeactivatedError(bytes32 key);
  error PoolAlreadyActiveError(bytes32 key);
  error PoolAlreadyExistsError(bytes32 key);
}
