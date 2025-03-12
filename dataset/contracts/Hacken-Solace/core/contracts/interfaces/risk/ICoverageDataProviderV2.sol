// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

/**
 * @title ICoverageDataProviderV2
 * @author solace.fi
 * @notice Holds underwriting pool amounts in `USD`. Provides information to the [**Risk Manager**](./RiskManager.sol) that is the maximum amount of cover that `Solace` protocol can sell as a coverage.
*/
interface ICoverageDataProviderV2 {
  
    /***************************************
     EVENTS
    ***************************************/

    /// @notice Emitted when the underwriting pool is set.
    event UnderwritingPoolSet(string uwpName, uint256 amount);

    /// @notice Emitted when underwriting pool is removed.
    event UnderwritingPoolRemoved(string uwpName);

    /// @notice Emitted when underwriting pool updater is set.
    event UwpUpdaterSet(address uwpUpdater);

    /// @notice Emitted when underwriting pool updater is removed.
    event UwpUpdaterRemoved(address uwpUpdater);

    /***************************************
     MUTUATOR FUNCTIONS
    ***************************************/

    /**
      * @notice Resets the underwriting pool balances.
      * @param uwpNames The underwriting pool values to set.
      * @param amounts The underwriting pool balances.
    */
    function set(string[] calldata uwpNames, uint256[] calldata amounts) external;

    /**
     * @notice Removes the given underwriting pool.
     * @param uwpNames The underwriting pool names to remove.
    */
    function remove(string[] calldata uwpNames) external;

    /***************************************
     VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Returns the balance of the underwriting pool in `USD`.
     * @param uwpName The underwriting pool name to get balance.
     * @return amount The balance of the underwriting pool in `USD`.
    */
    function balanceOf(string memory uwpName) external view returns (uint256 amount); 

    /**
     * @notice Returns underwriting pool name for given index.
     * @param index The underwriting pool index to get.
     * @return uwpName The underwriting pool name.
    */
    function poolOf(uint256 index) external view returns (string memory uwpName);

    /**
     * @notice Returns if given address is a valid underwriting pool updater.
     * @param updater The address to check.
     * @return status True if the address is valid updater.
    */
    function isUpdater(address updater) external view returns (bool status);

    /**
     * @notice Returns updater for given index.
     * @param index The index to get updater.
     * @return updater The updater address.
    */
    function updaterAt(uint256 index) external view returns (address updater);

    /**
     * @notice Returns the length of the updaters.
     * @return count The updater count.
    */
    function numsOfUpdater() external view returns (uint256 count);
    
    /***************************************
     GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Sets the underwriting pool bot updater.
     * @param updater The bot address to set.
    */
    function addUpdater(address updater) external;

    /**
     * @notice Sets the underwriting pool bot updater.
     * @param updater The bot address to set.
    */
    function removeUpdater(address updater) external;
}
