// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the PoolRegistry contract, a tuned ContractsRegistry contract. Its purpose is the management of
 * proposal pools, GovPools and contracts related to GovPools.
 * The owner of this contract is capable of upgrading pools' implementation via the ProxyBeacon pattern
 */
interface IPoolRegistry {
    /// @notice The function to add the pool proxy to the registry (called by the PoolFactory)
    /// @param name the type of the pool
    /// @param poolAddress the address of the pool to add
    function addProxyPool(string calldata name, address poolAddress) external;

    /// @notice The function to check if the given address is a valid GovPool
    /// @param potentialPool the address to inspect
    /// @return true if the address is a GovPool, false otherwise
    function isGovPool(address potentialPool) external view returns (bool);
}
