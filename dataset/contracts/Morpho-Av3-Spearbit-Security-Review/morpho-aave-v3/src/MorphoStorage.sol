// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IRewardsManager} from "./interfaces/IRewardsManager.sol";
import {IPool, IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPool.sol";

import {Types} from "./libraries/Types.sol";
import {Constants} from "./libraries/Constants.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title MorphoStorage
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice The storage shared by Morpho's contracts.
abstract contract MorphoStorage is Initializable, Ownable2StepUpgradeable {
    /* IMMUTABLES */

    IPool internal immutable _POOL; // The address of the pool.
    IPoolAddressesProvider internal immutable _ADDRESSES_PROVIDER; // The address of the pool addresses provider.
    uint8 internal immutable _E_MODE_CATEGORY_ID; // The e-mode category of the deployed Morpho.

    /* STORAGE */

    address[] internal _marketsCreated; // Keeps track of the created markets.
    mapping(address => Types.Market) internal _market; // The market data.
    mapping(address => Types.MarketBalances) internal _marketBalances; // The market balances data.
    mapping(address => EnumerableSet.AddressSet) internal _userCollaterals; // The collateral markets entered by a user.
    mapping(address => EnumerableSet.AddressSet) internal _userBorrows; // The borrow markets entered by a user.
    mapping(address => mapping(address => bool)) internal _isManaging; // Whether a user is allowed to borrow or withdraw on behalf of another user. delegator => manager => bool
    mapping(address => uint256) internal _userNonce; // The nonce of a user. Used to prevent replay attacks.

    Types.Iterations internal _defaultIterations; // The default iterations values to use in the matching process.

    address internal _positionsManager; // The address of the positions manager on which calls are delegated to.
    IRewardsManager internal _rewardsManager; // The address of the rewards manager to track pool rewards for users.

    address internal _treasuryVault; // The address of the treasury vault, recipient of the reserve fee.
    bool internal _isClaimRewardsPaused; // Whether claiming rewards is paused or not.

    /// @dev The contract is automatically marked as initialized when deployed to prevent hijacking the implementation contract.
    /// @param addressesProvider The address of the pool addresses provider.
    /// @param eModeCategoryId The e-mode category of the deployed Morpho. 0 for the general mode.
    constructor(address addressesProvider, uint8 eModeCategoryId) {
        _disableInitializers();

        _ADDRESSES_PROVIDER = IPoolAddressesProvider(addressesProvider);
        _POOL = IPool(_ADDRESSES_PROVIDER.getPool());

        _E_MODE_CATEGORY_ID = eModeCategoryId;
    }
}
