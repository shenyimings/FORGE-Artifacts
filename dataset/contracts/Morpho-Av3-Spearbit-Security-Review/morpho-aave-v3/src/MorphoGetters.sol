// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorphoGetters} from "./interfaces/IMorpho.sol";

import {Types} from "./libraries/Types.sol";
import {MarketLib} from "./libraries/MarketLib.sol";
import {MarketBalanceLib} from "./libraries/MarketBalanceLib.sol";

import {BucketDLL} from "@morpho-data-structures/BucketDLL.sol";
import {LogarithmicBuckets} from "@morpho-data-structures/LogarithmicBuckets.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {MorphoInternal} from "./MorphoInternal.sol";

/// @title MorphoGetters
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Abstract contract exposing all accessible getters.
abstract contract MorphoGetters is IMorphoGetters, MorphoInternal {
    using MarketLib for Types.Market;
    using MarketBalanceLib for Types.MarketBalances;

    using BucketDLL for BucketDLL.List;
    using EnumerableSet for EnumerableSet.AddressSet;

    /* STORAGE */

    /// @notice Returns the pool address.
    function POOL() external view returns (address) {
        return address(_POOL);
    }

    /// @notice Returns the addresses provider address.
    function ADDRESSES_PROVIDER() external view returns (address) {
        return address(_ADDRESSES_PROVIDER);
    }

    /// @notice Returns the domain separator of the EIP712.
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    /// @notice Returns the e-mode category ID of Morpho on the Aave protocol.
    function E_MODE_CATEGORY_ID() external view returns (uint256) {
        return _E_MODE_CATEGORY_ID;
    }

    /// @notice Returns the market data.
    function market(address underlying) external view returns (Types.Market memory) {
        return _market[underlying];
    }

    /// @notice Returns the list of the markets created.
    function marketsCreated() external view returns (address[] memory) {
        return _marketsCreated;
    }

    /// @notice Returns the scaled balance of `user` on the `underlying` market, supplied on pool (with `underlying` decimals).
    function scaledPoolSupplyBalance(address underlying, address user) external view returns (uint256) {
        return _marketBalances[underlying].scaledPoolSupplyBalance(user);
    }

    /// @notice Returns the scaled balance of `user` on the `underlying` market, supplied peer-to-peer (with `underlying` decimals).
    function scaledP2PSupplyBalance(address underlying, address user) external view returns (uint256) {
        return _marketBalances[underlying].scaledP2PSupplyBalance(user);
    }

    /// @notice Returns the scaled balance of `user` on the `underlying` market, borrowed from pool (with `underlying` decimals).
    function scaledPoolBorrowBalance(address underlying, address user) external view returns (uint256) {
        return _marketBalances[underlying].scaledPoolBorrowBalance(user);
    }

    //// @notice Returns the scaled balance of `user` on the `underlying` market, borrowed peer-to-peer (with `underlying` decimals).
    function scaledP2PBorrowBalance(address underlying, address user) external view returns (uint256) {
        return _marketBalances[underlying].scaledP2PBorrowBalance(user);
    }

    /// @notice Returns the scaled balance of `user` on the `underlying` market, supplied on pool & used as collateral (with `underlying` decimals).
    function scaledCollateralBalance(address underlying, address user) external view returns (uint256) {
        return _marketBalances[underlying].scaledCollateralBalance(user);
    }

    /// @notice Returns the total supply balance of `user` on the `underlying` market (in underlying).
    function supplyBalance(address underlying, address user) external view returns (uint256) {
        (, Types.Indexes256 memory indexes) = _computeIndexes(underlying);

        return _getUserSupplyBalanceFromIndexes(underlying, user, indexes);
    }

    /// @notice Returns the total borrow balance of `user` on the `underlying` market (in underlying).
    function borrowBalance(address underlying, address user) external view returns (uint256) {
        (, Types.Indexes256 memory indexes) = _computeIndexes(underlying);

        return _getUserBorrowBalanceFromIndexes(underlying, user, indexes);
    }

    /// @notice Returns the supply collateral balance of `user` on the `underlying` market (in underlying).
    function collateralBalance(address underlying, address user) external view returns (uint256) {
        return _getUserCollateralBalanceFromIndex(underlying, user, _POOL.getReserveNormalizedIncome(underlying));
    }

    /// @notice Returns the list of collateral underlyings of `user`.
    function userCollaterals(address user) external view returns (address[] memory) {
        return _userCollaterals[user].values();
    }

    /// @notice Returns the list of borrowed underlyings of `user`.
    function userBorrows(address user) external view returns (address[] memory) {
        return _userBorrows[user].values();
    }

    /// @notice Returns whether `manager` is a manager of `delegator`.
    function isManaging(address delegator, address manager) external view returns (bool) {
        return _isManaging[delegator][manager];
    }

    /// @notice Returns the nonce of `user` for the manager approval signature.
    function userNonce(address user) external view returns (uint256) {
        return _userNonce[user];
    }

    /// @notice Returns the default iterations.
    function defaultIterations() external view returns (Types.Iterations memory) {
        return _defaultIterations;
    }

    /// @notice Returns the address of the positions manager.
    function positionsManager() external view returns (address) {
        return _positionsManager;
    }

    /// @notice Returns the address of the rewards manager.
    function rewardsManager() external view returns (address) {
        return address(_rewardsManager);
    }

    /// @notice Returns the address of the treasury vault.
    function treasuryVault() external view returns (address) {
        return _treasuryVault;
    }

    /// @notice Returns whether the claim rewards is paused or not.
    function isClaimRewardsPaused() external view returns (bool) {
        return _isClaimRewardsPaused;
    }

    /// @notice Returns the updated indexes (peer-to-peer and pool).
    function updatedIndexes(address underlying) external view returns (Types.Indexes256 memory indexes) {
        (, indexes) = _computeIndexes(underlying);
    }

    /// @notice Returns the liquidity data about the position of `user`.
    /// @param user The address of the user to get the liquidity data for.
    /// @return The liquidity data of the user.
    function liquidityData(address user) external view returns (Types.LiquidityData memory) {
        return _liquidityData(user);
    }

    /// @notice Returns the account after `user` in the same bucket of the corresponding market side.
    /// @dev Input address zero to get the head of the bucket.
    /// @param underlying The address of the underlying asset.
    /// @param position The position type, either pool or peer-to-peer and either supply or borrow.
    function getNext(address underlying, Types.Position position, address user) external view returns (address) {
        LogarithmicBuckets.Buckets storage buckets = _getBuckets(underlying, position);
        uint256 userBalance = buckets.valueOf[user];
        uint256 userBucket = LogarithmicBuckets.computeBucket(userBalance);

        return buckets.buckets[userBucket].getNext(user);
    }

    /// @notice Returns the buckets mask of the corresponding market side.
    /// @param underlying The address of the underlying asset.
    /// @param position The position type, either pool or peer-to-peer and either supply or borrow.
    function getBucketsMask(address underlying, Types.Position position) external view returns (uint256) {
        return _getBuckets(underlying, position).bucketsMask;
    }
}
