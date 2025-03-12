// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorpho} from "./interfaces/IMorpho.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IPoolToken} from "./interfaces/aave/IPoolToken.sol";
import {IRewardsManager} from "./interfaces/IRewardsManager.sol";
import {IScaledBalanceToken} from "@aave-v3-core/interfaces/IScaledBalanceToken.sol";
import {IRewardsController} from "@aave-v3-periphery/rewards/interfaces/IRewardsController.sol";

import {Types} from "./libraries/Types.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";

/// @title RewardsManager
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Contract managing Aave's protocol rewards.
contract RewardsManager is IRewardsManager, Initializable {
    using SafeCast for uint256;

    /* STRUCTS */

    struct UserAssetBalance {
        address asset; // The rewarded asset (either aToken or debt token).
        uint256 balance; // The user balance of this asset (in asset decimals).
        uint256 scaledTotalSupply; // The scaled total supply of this asset.
    }

    struct UserData {
        uint128 index; // The user's index for a specific (asset, reward) pair.
        uint128 accrued; // The user's accrued rewards for a specific (asset, reward) pair (in reward token decimals).
    }

    struct RewardData {
        uint128 index; // The current index for a specific reward token.
        uint128 lastUpdateTimestamp; // The last timestamp the index was updated.
        mapping(address => UserData) usersData; // Users data. user -> UserData
    }

    /* IMMUTABLES */

    IRewardsController internal immutable _REWARDS_CONTROLLER; // The rewards controller is supposed not to change depending on the asset.
    IMorpho internal immutable _MORPHO; // The address of the main Morpho contract.
    IPool internal immutable _POOL; // The address of the Aave pool.

    /* STORAGE */

    mapping(address => mapping(address => RewardData)) internal _localAssetData; // The local data related to a given asset (either aToken or debt token). asset -> reward -> RewardData

    /* EVENTS */

    /// @dev Emitted when rewards of an asset are accrued on behalf of a user.
    /// @param asset The address of the incentivized asset.
    /// @param reward The address of the reward token.
    /// @param user The address of the user that rewards are accrued on behalf of.
    /// @param assetIndex The reward index for the asset (same as the user's index for this asset when the event is logged).
    /// @param rewardsAccrued The amount of rewards accrued.
    event Accrued(
        address indexed asset, address indexed reward, address indexed user, uint256 assetIndex, uint256 rewardsAccrued
    );

    /* ERRORS */

    /// @notice Thrown when only the main Morpho contract can call the function.
    error OnlyMorpho();

    /// @notice Thrown when an invalid asset is passed to accrue rewards.
    error InvalidAsset();

    /// @notice Thrown when the the zero address is passed as a parameter.
    error AddressIsZero();

    /* MODIFIERS */

    /// @notice Prevents a user to call function allowed for the main Morpho contract only.
    modifier onlyMorpho() {
        if (msg.sender != address(_MORPHO)) revert OnlyMorpho();
        _;
    }

    /* CONSTRUCTOR */

    /// @notice Initializes immutable variables.
    /// @param _rewardsController The address of the Aave rewards controller.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _pool The address of the Aave _pool.
    constructor(address _rewardsController, address _morpho, address _pool) {
        if (_rewardsController == address(0) || _morpho == address(0) || _pool == address(0)) revert AddressIsZero();
        _disableInitializers();

        _REWARDS_CONTROLLER = IRewardsController(_rewardsController);
        _MORPHO = IMorpho(_morpho);
        _POOL = IPool(_pool);
    }

    /* EXTERNAL */

    /// @notice Accrues unclaimed rewards for the given assets and returns the total unclaimed rewards.
    /// @param assets The assets for which to accrue rewards (aToken or variable debt token).
    /// @param user The address of the user.
    /// @return rewardsList The list of reward tokens.
    /// @return claimedAmounts The list of claimed reward amounts.
    function claimRewards(address[] calldata assets, address user)
        external
        onlyMorpho
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        rewardsList = _REWARDS_CONTROLLER.getRewardsList();
        claimedAmounts = new uint256[](rewardsList.length);

        _updateDataMultiple(user, _getUserAssetBalances(assets, user));

        for (uint256 i; i < assets.length; ++i) {
            address asset = assets[i];

            for (uint256 j; j < rewardsList.length; ++j) {
                uint256 rewardAmount = _localAssetData[asset][rewardsList[j]].usersData[user].accrued;

                if (rewardAmount != 0) {
                    claimedAmounts[j] += rewardAmount;
                    _localAssetData[asset][rewardsList[j]].usersData[user].accrued = 0;
                }
            }
        }
    }

    /// @notice Updates the unclaimed rewards of a user.
    /// @dev Only called by Morpho at positions updates in the data structure.
    /// @param user The address of the user.
    /// @param asset The address of the reference asset of the distribution (aToken or variable debt token).
    /// @param userBalance The current user asset balance.
    function updateUserRewards(address user, address asset, uint256 userBalance) external onlyMorpho {
        _updateData(user, asset, userBalance, IScaledBalanceToken(asset).scaledTotalSupply());
    }

    /* GETTERS */

    function POOL() external view returns (address) {
        return address(_POOL);
    }

    function MORPHO() external view returns (address) {
        return address(_MORPHO);
    }

    function REWARDS_CONTROLLER() external view returns (address) {
        return address(_REWARDS_CONTROLLER);
    }

    /// @notice Returns user's accrued rewards for the specified assets and reward token
    /// @param assets The list of assets to retrieve accrued rewards.
    /// @param user The address of the user.
    /// @return totalAccrued The total amount of accrued rewards.
    function getUserAccruedRewards(address[] calldata assets, address user, address reward)
        external
        view
        returns (uint256 totalAccrued)
    {
        uint256 assetsLength = assets.length;

        for (uint256 i; i < assetsLength; ++i) {
            totalAccrued += _localAssetData[assets[i]][reward].usersData[user].accrued;
        }
    }

    /// @notice Returns user's rewards for the specified assets and for all reward tokens.
    /// @param assets The list of assets to retrieve rewards.
    /// @param user The address of the user.
    /// @return rewardsList The list of reward tokens.
    /// @return unclaimedAmounts The list of unclaimed reward amounts.
    function getAllUserRewards(address[] calldata assets, address user)
        external
        view
        returns (address[] memory rewardsList, uint256[] memory unclaimedAmounts)
    {
        UserAssetBalance[] memory userAssetBalances = _getUserAssetBalances(assets, user);
        rewardsList = _REWARDS_CONTROLLER.getRewardsList();
        uint256 rewardsListLength = rewardsList.length;
        unclaimedAmounts = new uint256[](rewardsListLength);

        // Add unrealized rewards from user to unclaimed rewards.
        for (uint256 i; i < userAssetBalances.length; ++i) {
            for (uint256 j; j < rewardsListLength; ++j) {
                unclaimedAmounts[j] +=
                    _localAssetData[userAssetBalances[i].asset][rewardsList[j]].usersData[user].accrued;

                if (userAssetBalances[i].balance == 0) continue;

                unclaimedAmounts[j] += _getPendingRewards(user, rewardsList[j], userAssetBalances[i]);
            }
        }
    }

    /// @notice Returns user's rewards for the specified assets and reward token.
    /// @param assets The list of assets to retrieve rewards.
    /// @param user The address of the user.
    /// @param reward The address of the reward token
    /// @return The user's rewards in reward token.
    function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256) {
        return _getUserReward(user, reward, _getUserAssetBalances(assets, user));
    }

    /// @notice Returns the user's index for the specified asset and reward token.
    /// @param user The address of the user.
    /// @param asset The address of the reference asset of the distribution (aToken or variable debt token).
    /// @param reward The address of the reward token.
    /// @return The user's index.
    function getUserAssetIndex(address user, address asset, address reward) external view returns (uint256) {
        return _localAssetData[asset][reward].usersData[user].index;
    }

    /* INTERNAL */

    /// @dev Updates the state of the distribution for the specified reward.
    /// @param localRewardData The local reward's data.
    /// @param asset The asset being rewarded.
    /// @param reward The address of the reward token.
    /// @param totalSupply The current total supply of underlying assets for this distribution.
    /// @param assetUnit The asset's unit (10**decimals).
    /// @return newIndex The new distribution index.
    /// @return indexUpdated True if the index was updated, false otherwise.
    function _updateRewardData(
        RewardData storage localRewardData,
        address asset,
        address reward,
        uint256 totalSupply,
        uint256 assetUnit
    ) internal returns (uint256 newIndex, bool indexUpdated) {
        uint256 oldIndex;
        (oldIndex, newIndex) = _getAssetIndex(localRewardData, asset, reward, totalSupply, assetUnit);

        if (newIndex != oldIndex) {
            indexUpdated = true;
            localRewardData.index = newIndex.toUint128();
        }

        // Not safe casting because 2^128 is large enough.
        localRewardData.lastUpdateTimestamp = uint128(block.timestamp);
    }

    /// @dev Updates the state of the distribution for the specific user.
    /// @param localRewardData The local reward's data
    /// @param user The address of the user.
    /// @param userBalance The current user asset balance.
    /// @param newAssetIndex The new index of the asset distribution.
    /// @param assetUnit The asset's unit (10**decimals).
    /// @return rewardsAccrued The rewards accrued since the last update.
    /// @return dataUpdated True if the data was updated, false otherwise.
    function _updateUserData(
        RewardData storage localRewardData,
        address user,
        uint256 userBalance,
        uint256 newAssetIndex,
        uint256 assetUnit
    ) internal returns (uint256 rewardsAccrued, bool dataUpdated) {
        uint256 userIndex = localRewardData.usersData[user].index;

        if ((dataUpdated = userIndex != newAssetIndex)) {
            // Already checked for overflow in _updateRewardData.
            localRewardData.usersData[user].index = uint128(newAssetIndex);

            if (userBalance != 0) {
                rewardsAccrued = _getRewards(userBalance, newAssetIndex, userIndex, assetUnit);

                // Not safe casting because 2^128 is large enough.
                localRewardData.usersData[user].accrued += uint128(rewardsAccrued);
            }
        }
    }

    /// @dev Iterates and accrues all the rewards for asset of the specific user.
    /// @param user The user address.
    /// @param asset The address of the reference asset of the distribution.
    /// @param userBalance The current user asset balance.
    /// @param scaledTotalSupply The current scaled total supply for this distribution.
    function _updateData(address user, address asset, uint256 userBalance, uint256 scaledTotalSupply) internal {
        address[] memory availableRewards = _REWARDS_CONTROLLER.getRewardsByAsset(asset);
        if (availableRewards.length == 0) return;

        unchecked {
            uint256 assetUnit = 10 ** _REWARDS_CONTROLLER.getAssetDecimals(asset);

            for (uint128 i; i < availableRewards.length; ++i) {
                address reward = availableRewards[i];
                RewardData storage localRewardData = _localAssetData[asset][reward];

                (uint256 newAssetIndex, bool rewardDataUpdated) =
                    _updateRewardData(localRewardData, asset, reward, scaledTotalSupply, assetUnit);

                (uint256 rewardsAccrued, bool userDataUpdated) =
                    _updateUserData(localRewardData, user, userBalance, newAssetIndex, assetUnit);

                if (rewardDataUpdated || userDataUpdated) {
                    emit Accrued(asset, reward, user, newAssetIndex, rewardsAccrued);
                }
            }
        }
    }

    /// @dev Accrues all the rewards of the assets specified in the userAssetBalances list.
    /// @param user The address of the user.
    /// @param _userAssetBalances The list of structs with the user balance and total supply of a set of assets.
    function _updateDataMultiple(address user, UserAssetBalance[] memory _userAssetBalances) internal {
        for (uint256 i; i < _userAssetBalances.length; ++i) {
            _updateData(
                user,
                _userAssetBalances[i].asset,
                _userAssetBalances[i].balance,
                _userAssetBalances[i].scaledTotalSupply
            );
        }
    }

    /// @dev Returns the accrued unclaimed amount of a reward from a user over a list of distribution.
    /// @param user The address of the user.
    /// @param reward The address of the reward token.
    /// @param _userAssetBalances List of structs with the user balance and total supply of a set of assets.
    /// @return unclaimedRewards The accrued rewards for the user until the moment.
    function _getUserReward(address user, address reward, UserAssetBalance[] memory _userAssetBalances)
        internal
        view
        returns (uint256 unclaimedRewards)
    {
        uint256 userAssetBalancesLength = _userAssetBalances.length;

        // Add unrealized rewards.
        for (uint256 i; i < userAssetBalancesLength; ++i) {
            unclaimedRewards += _localAssetData[_userAssetBalances[i].asset][reward].usersData[user].accrued;

            if (_userAssetBalances[i].balance == 0) continue;

            unclaimedRewards += _getPendingRewards(user, reward, _userAssetBalances[i]);
        }
    }

    /// @dev Computes the pending (not yet accrued) rewards since the last user action.
    /// @param user The address of the user.
    /// @param reward The address of the reward token.
    /// @param _userAssetBalance The struct with the user balance and total supply of the incentivized asset.
    /// @return The pending rewards for the user since the last user action.
    function _getPendingRewards(address user, address reward, UserAssetBalance memory _userAssetBalance)
        internal
        view
        returns (uint256)
    {
        RewardData storage localRewardData = _localAssetData[_userAssetBalance.asset][reward];

        uint256 assetUnit;
        unchecked {
            assetUnit = 10 ** _REWARDS_CONTROLLER.getAssetDecimals(_userAssetBalance.asset);
        }

        (, uint256 nextIndex) = _getAssetIndex(
            localRewardData, _userAssetBalance.asset, reward, _userAssetBalance.scaledTotalSupply, assetUnit
        );

        return _getRewards(_userAssetBalance.balance, nextIndex, localRewardData.usersData[user].index, assetUnit);
    }

    /// @dev Computes user's accrued rewards on a distribution.
    /// @param userBalance The current user asset balance.
    /// @param _reserveIndex The current index of the distribution.
    /// @param _userIndex The index stored for the user, representing its staking moment.
    /// @param assetUnit The asset's unit (10**decimals).
    /// @return rewards The rewards accrued.
    function _getRewards(uint256 userBalance, uint256 _reserveIndex, uint256 _userIndex, uint256 assetUnit)
        internal
        pure
        returns (uint256 rewards)
    {
        rewards = userBalance * (_reserveIndex - _userIndex);
        assembly {
            rewards := div(rewards, assetUnit)
        }
    }

    /// @dev Computes the next value of an specific distribution index, with validations.
    /// @param localRewardData The local reward's data.
    /// @param asset The asset being rewarded.
    /// @param reward The address of the reward token.
    /// @param totalSupply The current total supply of underlying assets for this distribution.
    /// @param assetUnit The asset's unit (10**decimals).
    /// @return The former index and the new index in this order.
    function _getAssetIndex(
        RewardData storage localRewardData,
        address asset,
        address reward,
        uint256 totalSupply,
        uint256 assetUnit
    ) internal view returns (uint256, uint256) {
        uint256 currentTimestamp = block.timestamp;

        if (currentTimestamp == localRewardData.lastUpdateTimestamp) {
            return (localRewardData.index, localRewardData.index);
        }

        (uint256 rewardIndex, uint256 emissionPerSecond, uint256 lastUpdateTimestamp, uint256 distributionEnd) =
            _REWARDS_CONTROLLER.getRewardsData(asset, reward);

        if (
            emissionPerSecond == 0 || totalSupply == 0 || lastUpdateTimestamp == currentTimestamp
                || lastUpdateTimestamp >= distributionEnd
        ) return (localRewardData.index, rewardIndex);

        currentTimestamp = currentTimestamp > distributionEnd ? distributionEnd : currentTimestamp;
        uint256 totalEmitted = emissionPerSecond * (currentTimestamp - lastUpdateTimestamp) * assetUnit;
        assembly {
            totalEmitted := div(totalEmitted, totalSupply)
        }
        return (localRewardData.index, (totalEmitted + rewardIndex));
    }

    /// @dev Returns user balances and total supply of all the assets specified by the assets parameter.
    /// @param assets List of assets to retrieve user balance and total supply.
    /// @param user The address of the user.
    /// @return userAssetBalances The list of structs with user balance and total supply of the given assets.
    function _getUserAssetBalances(address[] calldata assets, address user)
        internal
        view
        returns (UserAssetBalance[] memory userAssetBalances)
    {
        uint256 assetsLength = assets.length;
        userAssetBalances = new UserAssetBalance[](assetsLength);

        for (uint256 i; i < assetsLength; ++i) {
            address asset = assets[i];
            userAssetBalances[i].asset = asset;

            Types.Market memory market =
                _MORPHO.market(IPoolToken(userAssetBalances[i].asset).UNDERLYING_ASSET_ADDRESS());

            if (asset == market.aToken) {
                userAssetBalances[i].balance = _MORPHO.scaledPoolSupplyBalance(market.underlying, user);
            } else if (asset == market.variableDebtToken) {
                userAssetBalances[i].balance = _MORPHO.scaledPoolBorrowBalance(market.underlying, user);
            } else {
                revert InvalidAsset();
            }

            userAssetBalances[i].scaledTotalSupply = IScaledBalanceToken(asset).scaledTotalSupply();
        }
    }
}
