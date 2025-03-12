// SPDX-License-Identifier: MIT

/**
 __      __  _____ _______________________________________   
/  \    /  \/  _  \\______   \______   \_   _____/\______ \  
\   \/\/   /  /_\  \|       _/|     ___/|    __)_  |    |  \ 
 \        /    |    \    |   \|    |    |        \ |    `   \
  \__/\  /\____|__  /____|_  /|____|   /_______  //_______  /
       \/         \/       \/                  \/         \/ 
 */

pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";

/**
 * @title Exchange pool processor contract.
 * @dev Keeps an enumerable set of designated exchange addresses as well as a single primary pool address.
 */
contract WarpedPoolManager is IPoolManager, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Set of exchange pool addresses.
    EnumerableSet.AddressSet internal _exchangePools;

    /// @notice Primary exchange pool address.
    address public override primaryPool;

    /// @notice Emitted when an exchange pool address is added to the set of tracked pool addresses.
    event ExchangePoolAdded(address exchangePool);

    /// @notice Emitted when an exchange pool address is removed from the set of tracked pool addresses.
    event ExchangePoolRemoved(address exchangePool);

    /// @notice Emitted when the primary pool address is updated.
    event PrimaryPoolUpdated(address oldPrimaryPool, address newPrimaryPool);

    /**
     * @notice Add an address to the set of exchange pool addresses.
     * @dev Nothing happens if the pool already exists in the set.
     * @param poolAddress Address of the pool to add.
     */
    function addExchangePool(address poolAddress) external onlyOwner {
        require(poolAddress != address(0), "Zero address passed");
        if (_exchangePools.add(poolAddress)) {
            emit ExchangePoolAdded(poolAddress);
        }
    }

    /**
     * @notice Remove an address from the set of exchange pool addresses.
     * @dev Remove from _exchangePools when given poolAddress is different to the current primaryPool, otherwise revert.
     * Nothing happens if the pool doesn't exist in the set.
     * @param poolAddress Address of the pool to remove.
     */
    function removeExchangePool(address poolAddress) external onlyOwner {
        require(poolAddress != primaryPool, "Primary pool cannot be removed");
        if (_exchangePools.remove(poolAddress)) {
            emit ExchangePoolRemoved(poolAddress);
        }
    }

    /**
     * @notice Set exchange pool address as primary pool.
     * @dev To prevent issues, only addresses inside the set of exchange pool addresses can be selected as primary pool.
     * @param exchangePool Address of exchange pool to set as primary pool.
     */
    function setPrimaryPool(address exchangePool) external onlyOwner {
        require(_exchangePools.contains(exchangePool), "Not registered as exchange pool");
        require(primaryPool != exchangePool, "Already primary pool address");

        address oldPrimaryPool = primaryPool;
        primaryPool = exchangePool;

        emit PrimaryPoolUpdated(oldPrimaryPool, exchangePool);
    }

    /**
     * @notice Check if the given address is pool address.
     * @param addr Address to check.
     * @return bool True if the given address is pool address.
     */
    function isPoolAddress(address addr) external view override returns (bool) {
        return _exchangePools.contains(addr);
    }
}
