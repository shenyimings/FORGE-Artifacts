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
    /* STORAGE */

    /// @dev The address of Aave's pool.
    IPool internal _pool;

    /// @dev The address of the pool addresses provider.
    IPoolAddressesProvider internal _addressesProvider;

    /// @dev The e-mode category of the deployed Morpho.
    uint8 internal _eModeCategoryId;

    /// @dev The list of created markets.
    address[] internal _marketsCreated;

    /// @dev The markets data.
    mapping(address => Types.Market) internal _market;

    /// @dev The markets balances data.
    mapping(address => Types.MarketBalances) internal _marketBalances;

    /// @dev The collateral markets entered by users.
    mapping(address => EnumerableSet.AddressSet) internal _userCollaterals;

    /// @dev The borrow markets entered by users.
    mapping(address => EnumerableSet.AddressSet) internal _userBorrows;

    /// @dev Users allowances to manage other users' accounts. delegator => manager => isManagedBy
    mapping(address => mapping(address => bool)) internal _isManagedBy;

    /// @dev The nonce of users. Used to prevent replay attacks with EIP-712 signatures.
    mapping(address => uint256) internal _userNonce;

    /// @dev The default number of iterations to use in the matching process.
    Types.Iterations internal _defaultIterations;

    /// @dev The address of the positions manager on which calls are delegated to.
    address internal _positionsManager;

    /// @dev The address of the rewards manager to track pool rewards for users.
    IRewardsManager internal _rewardsManager;

    /// @dev The address of the treasury vault, recipient of the reserve fee.
    address internal _treasuryVault;

    /// @dev Whether claiming rewards is paused or not.
    bool internal _isClaimRewardsPaused;

    /* CONSTRUCTOR */

    /// @notice Contract constructor.
    /// @dev The implementation contract disables initialization upon deployment to avoid being hijacked.
    constructor() {
        _disableInitializers();
    }
}
