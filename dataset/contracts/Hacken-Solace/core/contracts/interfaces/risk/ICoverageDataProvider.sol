// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

/**
 * @title ICoverageDataProvider
 * @author solace.fi
 * @notice Holds underwriting pool amounts in `USD`. Provides information to the [**Risk Manager**](./RiskManager.sol) that is the maximum amount of cover that `Solace` protocol can sell as a coverage.
*/
interface ICoverageDataProvider {
    /***************************************
     EVENTS
    ***************************************/

    /// @notice Emitted when the underwriting pool is set.
    event UnderwritingPoolSet(string uwpName, uint256 amount);

    /// @notice Emitted when underwriting pool is removed.
    event UnderwritingPoolRemoved(string uwpName);

    /// @notice Emitted when underwriting pool updater is set.
    event UwpUpdaterSet(address uwpUpdater);

    /***************************************
     MUTUATOR FUNCTIONS
    ***************************************/

    /**
      * @notice Resets the underwriting pool balances.
      * @param uwpNames The underwriting pool values to set.
      * @param amounts The underwriting pool balances.
    */
    function reset(string[] calldata uwpNames, uint256[] calldata amounts) external;

    /**
     * @notice Sets the balance of the given underwriting pool.
     * @param uwpName The underwriting pool name to set balance.
     * @param amount The balance of the underwriting pool in `USD`.
    */
    function set(string calldata uwpName, uint256 amount) external;

    /**
     * @notice Removes the given underwriting pool.
     * @param uwpName The underwriting pool name to remove.
    */
    function remove(string calldata uwpName) external;

    /***************************************
     VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice The maximum amount of cover in `USD` that Solace as a whole can sell.
     * @return cover The max amount of cover in `USD`.
    */
    function maxCover() external view returns (uint256 cover);

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
     * @notice Returns the underwriting pool bot updater address.
     * @return uwpUpdater The bot address.
    */
    function getUwpUpdater() external view returns (address uwpUpdater);

    /***************************************
     GOVERNANCE FUNCTIONS
    ***************************************/
    
    /**
     * @notice Sets the underwriting pool bot updater.
     * @param uwpUpdater The bot address to set.
    */
    function setUwpUpdater(address uwpUpdater) external;
}
