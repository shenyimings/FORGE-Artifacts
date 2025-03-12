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

/**
 * @title Exchange pool processor abstract contract.
 * @dev Keeps an enumerable set of designated exchange addresses as well as a single primary pool address.
 */
interface IPoolManager {
    /// @notice Primary exchange pool address.
    function primaryPool() external view returns (address);

    /**
     * @notice Check if the given address is pool address.
     * @param addr Address to check.
     * @return bool True if the given address is pool address.
     */
    function isPoolAddress(address addr) external view returns (bool);
}
