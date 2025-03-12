// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/risk/ICoverageDataProvider.sol";
import "../interfaces/utils/IRegistry.sol";
import "../interfaces/ISOLACE.sol";
import "../utils/Governable.sol";

/**
 * @title  CoverageDataProvider
 * @author solace.fi
 * @notice Holds underwriting pool amounts in `USD`. Provides information to the [**Risk Manager**](./RiskManager.sol) that is the maximum amount of cover that `Solace` protocol can sell as a coverage.
*/
contract CoverageDataProvider is ICoverageDataProvider, Governable {

    /***************************************
     STATE VARIABLES
    ***************************************/

    /// @notice The balance of underwriting pool in usd.
    mapping(string => uint256) private _uwpBalanceOf;

    /// @notice The index to underwriting pool.
    mapping(uint256 => string) private _indexToUwp;

    /// @notice The underwriting pool to index.
    mapping(string => uint256) private _uwpToIndex;

    /// @notice The underwriting pool count
    uint256 public numOfPools;

    /// @notice The pool updater.
    address private _uwpUpdater;

    modifier canUpdate() {
      require(msg.sender == super.governance() || msg.sender == _uwpUpdater, "!governance");
      _;
    }

    /**
     * @notice Constructs the `CoverageDataProvider` contract.
     * @param governance The address of the [governor](/docs/protocol/governance).
    */
    // solhint-disable-next-line no-empty-blocks
    constructor(address governance) Governable(governance) {}

    /***************************************
     MUTUATOR FUNCTIONS
    ***************************************/
   
    /**
      * @notice Resets the underwriting pool balances.
      * @param uwpNames The underwriting pool values to set.
      * @param amounts The underwriting pool balances in `USD`.
    */
    function reset(string[] calldata uwpNames, uint256[] calldata amounts) external override canUpdate {
      require(uwpNames.length == amounts.length, "length mismatch");
      // delete current underwriting pools
      uint256 poolCount = numOfPools;
      for (uint256 i = poolCount; i > 0; i--) {
        string memory uwpName = _indexToUwp[i];
        delete _uwpToIndex[uwpName];
        delete _indexToUwp[i];
        delete _uwpBalanceOf[uwpName];
        emit UnderwritingPoolRemoved(uwpName);
      }

      // set new underwriting pools
      numOfPools = 0;
      for (uint256 i = 0; i < uwpNames.length; i++) {
        set(uwpNames[i], amounts[i]);
      }
    }

    /**
     * @notice Sets the balance of the given underwriting pool.
     * @param uwpName The underwriting pool name to set balance.
     * @param amount The balance of the underwriting pool in `USD`.
    */
    function set(string calldata uwpName, uint256 amount) public override canUpdate {
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

    /**
     * @notice Removes the given underwriting pool.
     * @param uwpName The underwriting pool name to remove.
    */
    function remove(string calldata uwpName) external override canUpdate {
      uint256 index = _uwpToIndex[uwpName];
      if (index == 0) return;

      uint256 poolCount = numOfPools;
      if (poolCount == 0) return;

      if (index != poolCount) {
        string memory lastPool = _indexToUwp[poolCount];
        _uwpToIndex[lastPool] = index;
        _indexToUwp[index] = lastPool;
      }

      delete _uwpToIndex[uwpName];
      delete _indexToUwp[poolCount];
      delete _uwpBalanceOf[uwpName];
      numOfPools -= 1;
      emit UnderwritingPoolRemoved(uwpName);
    }

    /***************************************
     VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Returns the maximum amount of cover in `USD` that Solace as a whole can sell.
     * @return cover The max amount of cover in `USD`.
    */
    function maxCover() external view override returns (uint256 cover) {
      // get pool balance
      uint256 pools = numOfPools;
      for (uint256 i = pools; i > 0; i--) {
        cover += balanceOf(_indexToUwp[i]);
      }
    }
   
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
     * @notice Returns the underwriting pool bot updater address.
     * @return uwpUpdater The bot address.
    */
    function getUwpUpdater() external view override returns (address uwpUpdater) {
      return _uwpUpdater;
    }

    /***************************************
     GOVERNANCE FUNCTIONS
    ***************************************/
    
    /**
     * @notice Sets the underwriting pool bot updater.
     * @param uwpUpdater The bot address to set.
    */
    function setUwpUpdater(address uwpUpdater) external override onlyGovernance {
      require(uwpUpdater != address(0x0), "zero address uwp updater");
      _uwpUpdater = uwpUpdater;
      emit UwpUpdaterSet(uwpUpdater);
    }
}
