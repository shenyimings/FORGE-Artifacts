// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/risk/ICoverageDataProviderV2.sol";
import "../interfaces/utils/IRegistry.sol";
import "../interfaces/ISOLACE.sol";
import "../utils/Governable.sol";

/**
 * @title  CoverageDataProviderV2
 * @author solace.fi
 * @notice Holds underwriting pool amounts in `USD`. Provides information to the [**Risk Manager**](./RiskManager.sol) that is the maximum amount of cover that `Solace` protocol can sell as a coverage.
*/
contract CoverageDataProviderV2 is ICoverageDataProviderV2, Governable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    /***************************************
     STATE VARIABLES
    ***************************************/

    /// @notice The balance of underwriting pool in usd.
    mapping(string => uint256) private _uwpBalanceOf;

    /// @notice The index to underwriting pool.
    mapping(uint256 => string) private _indexToUwp;

    /// @notice The underwriting pool to index.
    mapping(string => uint256) private _uwpToIndex;

    /// @notice The underwriting pool updaters.
    EnumerableSet.AddressSet private _updaters;

    /// @notice The underwriting pool count
    uint256 public numOfPools;

    /// @notice The max. coverage amount.
    uint256 public maxCover;

    /***************************************
     MODIFIERS FUNCTIONS
    ***************************************/
    
    modifier canUpdate() {
      require(msg.sender == super.governance() || isUpdater(msg.sender), "!governance");
      _;
    }

    /**
     * @notice Constructs the `CoverageDataProviderV2` contract.
     * @param _governance The address of the [governor](/docs/protocol/governance).
    */
    // solhint-disable-next-line no-empty-blocks
    constructor(address _governance) Governable(_governance) {}

    /***************************************
     MUTUATOR FUNCTIONS
    ***************************************/
   
    /**
      * @notice Resets the underwriting pool balances.
      * @param _uwpNames The underwriting pool values to set.
      * @param _amounts The underwriting pool balances in `USD`.
    */
    function set(string[] calldata _uwpNames, uint256[] calldata _amounts) external override nonReentrant canUpdate {
      require(_uwpNames.length == _amounts.length, "length mismatch");
      _set(_uwpNames, _amounts);
    }

    /**
     * @notice Removes the given underwriting pool.
     * @param uwpNames The underwriting pool names to remove.
    */
    function remove(string[] calldata uwpNames) external override canUpdate {
      _remove(uwpNames);
    }

    /***************************************
     VIEW FUNCTIONS
    ***************************************/
   
    /**
     * @notice Returns the balance of the underwriting pool in `USD`.
     * @param uwpName The underwriting pool name to get balance.
     * @return amount The balance of the underwriting pool in `USD`.
    */
    function balanceOf(string memory uwpName) public view override returns (uint256 amount) {
      return _uwpBalanceOf[uwpName];
    }

    /**
     * @notice Returns underwriting pool name for given index.
     * @param index The underwriting pool index to get.
     * @return uwpName The underwriting pool name.
    */
    function poolOf(uint256 index) external view override returns (string memory uwpName) {
      return _indexToUwp[index];
    }

    /**
     * @notice Returns if given address is a valid underwriting pool updater.
     * @param updater The address to check.
     * @return status True if the address is valid updater.
    */
    function isUpdater(address updater) public view override returns (bool status) {
      return _updaters.contains(updater);
    }

    /**
     * @notice Returns updater for given index.
     * @param index The index to get updater.
     * @return updater The updater address.
    */
    function updaterAt(uint256 index) external view override returns (address updater) {
        return _updaters.at(index);
    }

    /**
     * @notice Returns the length of the updaters.
     * @return count The updater count.
    */
    function numsOfUpdater() external view override returns (uint256 count) {
        return _updaters.length();
    }

    /***************************************
     INTERNAL FUNCTIONS
    ***************************************/

    /**
      * @notice Resets the underwriting pool balances.
      * @param uwpNames The underwriting pool values to set.
      * @param amounts The underwriting pool balances in `USD`.
    */
    function _set(string[] memory uwpNames, uint256[] memory amounts) internal {
      // delete current underwriting pools
      uint256 poolCount = numOfPools;
      string memory uwpName;

      for (uint256 i = poolCount; i > 0; i--) {
        uwpName = _indexToUwp[i];
        delete _uwpToIndex[uwpName];
        delete _indexToUwp[i];
        delete _uwpBalanceOf[uwpName];
        emit UnderwritingPoolRemoved(uwpName);
      }

      // set new underwriting pools
      uint256 cover = 0;
      numOfPools = 0;
      uint256 amount;
      for (uint256 i = 0; i < uwpNames.length; i++) {
        uwpName = uwpNames[i];
        amount = amounts[i];
        cover += amount;
        require(bytes(uwpName).length > 0, "empty underwriting pool name");
        
        _uwpBalanceOf[uwpName] = amount;
        if (_uwpToIndex[uwpName] == 0) {
          uint256 index = numOfPools;
          _uwpToIndex[uwpName] = ++index;
          _indexToUwp[index] = uwpName;
          numOfPools = index;
        }
        emit UnderwritingPoolSet(uwpName, amount);
      }
      maxCover = cover;
    }

    /**
     * @notice Removes the given underwriting pool.
     * @param uwpNames The underwriting pool names to remove.
    */
    function _remove(string[] memory uwpNames) internal {
      string memory uwpName;
      uint256 cover = maxCover;

      for (uint256 i = 0; i < uwpNames.length; i++) {
        uwpName = uwpNames[i];
        uint256 index = _uwpToIndex[uwpName];
        if (index == 0) return;

        uint256 poolCount = numOfPools;
        if (poolCount == 0) return;

        if (index != poolCount) {
          string memory lastPool = _indexToUwp[poolCount];
          _uwpToIndex[lastPool] = index;
          _indexToUwp[index] = lastPool;
        }

        cover -= _uwpBalanceOf[uwpName];
        delete _uwpToIndex[uwpName];
        delete _indexToUwp[poolCount];
        delete _uwpBalanceOf[uwpName];
        numOfPools -= 1;
        emit UnderwritingPoolRemoved(uwpName);
      }
      maxCover = cover;
    }

    /***************************************
     GOVERNANCE FUNCTIONS
    ***************************************/
    
    /**
     * @notice Sets the underwriting pool bot updater.
     * @param updater The bot address to set.
    */
    function addUpdater(address updater) external override onlyGovernance {
      require(updater != address(0x0), "zero address uwp updater");
      _updaters.add(updater);
      emit UwpUpdaterSet(updater);
    }

    /**
     * @notice Sets the underwriting pool bot updater.
     * @param updater The bot address to set.
    */
    function removeUpdater(address updater) external override onlyGovernance {
      if (!isUpdater(updater)) return;
      _updaters.remove(updater);
      emit UwpUpdaterRemoved(updater);
    }
}
