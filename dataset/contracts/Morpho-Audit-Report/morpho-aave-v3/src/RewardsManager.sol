// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorpho} from "./interfaces/IMorpho.sol";
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

    /* IMMUTABLES */

    /// @dev The address of Aave's rewards controller.
    /// @dev The rewards controller is, in theory, specific to an asset.
    ///      In practice, it is the same for all assets and it is supposed to be true for future assets as well.
    IRewardsController internal immutable _REWARDS_CONTROLLER;

    /// @dev The address of the Morpho protocol.
    IMorpho internal immutable _MORPHO;

    /* STORAGE */

    /// @dev The local data related to a given asset (either aToken or debt token). asset -> reward -> RewardData
    mapping(address => mapping(address => RewardData)) internal _localAssetData;

    /* MODIFIERS */

    /// @notice Prevents a user to call function allowed for the main Morpho contract only.
    modifier onlyMorpho() {
        if (msg.sender != address(_MORPHO)) revert OnlyMorpho();
        _;
    }

    /* CONSTRUCTOR */

    /// @notice Contract constructor.
    /// @dev The implementation contract disables initialization upon deployment to avoid being hijacked.
    /// @param rewardsController The address of the Aave rewards controller.
    /// @param morpho The address of the main Morpho contract.
    constructor(address rewardsController, address morpho) {
        if (rewardsController == address(0) || morpho == address(0)) revert AddressIsZero();
        _disableInitializers();

        _REWARDS_CONTROLLER = IRewardsController(rewardsController);
        _MORPHO = IMorpho(morpho);
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

    /// @notice Returns the Morpho protocol address.
    function MORPHO() external view returns (address) {
        return address(_MORPHO);
    }

    /// @notice Returns the rewards controller address.
    function REWARDS_CONTROLLER() external view returns (address) {
        return address(_REWARDS_CONTROLLER);
    }

    /// @notice Returns the last updated index and timestamp for a specific asset and reward token.
    /// @param asset The address of the asset.
    /// @param reward The address of the reward token.
    /// @return startingIndex The index from which the rewards manager begins tracking the rewards controller.
    /// @return index The last updated index.
    /// @return lastUpdateTimestamp The last updated timestamp.
    function getRewardData(address asset, address reward)
        external
        view
        returns (uint256 startingIndex, uint256 index, uint256 lastUpdateTimestamp)
    {
        RewardData storage localAssetData = _localAssetData[asset][reward];
        startingIndex = uint256(localAssetData.startingIndex);
        index = uint256(localAssetData.index);
        lastUpdateTimestamp = uint256(localAssetData.lastUpdateTimestamp);
    }

    /// @notice Returns the user's index and accrued rewards for a specific asset and rewards pair.
    /// @param asset The address of the asset.
    /// @param reward The address of the reward token.
    /// @param user The address of the user.
    /// @return index The user's index.
    /// @return accrued The user's accrued rewards.
    function getUserData(address asset, address reward, address user)
        external
        view
        returns (uint256 index, uint256 accrued)
    {
        UserData storage userData = _localAssetData[asset][reward].usersData[user];
        index = uint256(userData.index);
        accrued = uint256(userData.accrued);
    }

    /// @notice Returns user's accrued rewards for the specified assets and reward token
    /// @param assets The list of assets to retrieve accrued rewards.
    /// @param user The address of the user.
    /// @param reward The address of the reward token.
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

                if (userAssetBalances[i].scaledBalance == 0) continue;

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
    /// @dev If an already listed AaveV3 reward token is not yet tracked (startingIndex == 0), this view function ignores that it will get updated upon interaction.
    /// @param user The address of the user.
    /// @param asset The address of the reference asset of the distribution (aToken or variable debt token).
    /// @param reward The address of the reward token.
    /// @return The user's index.
    function getUserAssetIndex(address user, address asset, address reward) external view returns (uint256) {
        return _computeUserIndex(_localAssetData[asset][reward], user);
    }

    /// @notice Returns the virtually updated asset index for the specified asset and reward token.
    /// @param asset The address of the reference asset of the distribution (aToken or variable debt token).
    /// @param reward The address of the reward token.
    /// @return assetIndex The reward token's virtually updated asset index.
    function getAssetIndex(address asset, address reward) external view returns (uint256 assetIndex) {
        (, assetIndex) = _getAssetIndex(
            _localAssetData[asset][reward],
            asset,
            reward,
            IScaledBalanceToken(asset).scaledTotalSupply(),
            10 ** _REWARDS_CONTROLLER.getAssetDecimals(asset)
        );
    }

    /* INTERNAL */

    /// @dev Updates the state of the distribution for the specified reward.
    /// @param localRewardData The local reward's data.
    /// @param asset The asset being rewarded.
    /// @param reward The address of the reward token.
    /// @param scaledTotalSupply The current scaled total supply of underlying assets for this distribution.
    /// @param assetUnit The asset's unit (10**decimals).
    /// @return newIndex The new distribution index.
    /// @return indexUpdated True if the index was updated, false otherwise.
    function _updateRewardData(
        RewardData storage localRewardData,
        address asset,
        address reward,
        uint256 scaledTotalSupply,
        uint256 assetUnit
    ) internal returns (uint256 newIndex, bool indexUpdated) {
        uint256 oldIndex;
        (oldIndex, newIndex) = _getAssetIndex(localRewardData, asset, reward, scaledTotalSupply, assetUnit);

        // If this is the first initiation of the distribution, set the starting index.
        // In the case that rewards have already started accumulating, rewards will not be credited before this starting index.
        if (localRewardData.lastUpdateTimestamp == 0) {
            (,, uint256 lastUpdatedTimestampRC,) = _REWARDS_CONTROLLER.getRewardsData(asset, reward);
            // If the rewards controller has already started distributing rewards, set the starting index to the new index.
            // Rewards before this index will not be credited.
            if (lastUpdatedTimestampRC != 0) localRewardData.startingIndex = newIndex.toUint104();
        }

        if (newIndex != oldIndex) {
            indexUpdated = true;
            localRewardData.index = newIndex.toUint104();
        }

        localRewardData.lastUpdateTimestamp = block.timestamp.toUint32();
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
        uint256 userIndex = _computeUserIndex(localRewardData, user);

        if ((dataUpdated = userIndex != newAssetIndex)) {
            // Already checked for overflow in _updateRewardData.
            localRewardData.usersData[user].index = uint104(newAssetIndex);

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

            for (uint256 i; i < availableRewards.length; ++i) {
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
    /// @param userAssetBalances The list of structs with the user balance and total supply of a set of assets.
    function _updateDataMultiple(address user, UserAssetBalance[] memory userAssetBalances) internal {
        for (uint256 i; i < userAssetBalances.length; ++i) {
            _updateData(
                user,
                userAssetBalances[i].asset,
                userAssetBalances[i].scaledBalance,
                userAssetBalances[i].scaledTotalSupply
            );
        }
    }

    /// @dev Returns the accrued unclaimed amount of a reward from a user over a list of distribution.
    /// @param user The address of the user.
    /// @param reward The address of the reward token.
    /// @param userAssetBalances List of structs with the user balance and total supply of a set of assets.
    /// @return unclaimedRewards The accrued rewards for the user until the moment.
    function _getUserReward(address user, address reward, UserAssetBalance[] memory userAssetBalances)
        internal
        view
        returns (uint256 unclaimedRewards)
    {
        uint256 userAssetBalancesLength = userAssetBalances.length;

        // Add unrealized rewards.
        for (uint256 i; i < userAssetBalancesLength; ++i) {
            unclaimedRewards += _localAssetData[userAssetBalances[i].asset][reward].usersData[user].accrued;

            if (userAssetBalances[i].scaledBalance == 0) continue;

            unclaimedRewards += _getPendingRewards(user, reward, userAssetBalances[i]);
        }
    }

    /// @dev Computes the pending (not yet accrued) rewards since the last user action.
    /// @param user The address of the user.
    /// @param reward The address of the reward token.
    /// @param userAssetBalance The struct with the user balance and total supply of the incentivized asset.
    /// @return The pending rewards for the user since the last user action.
    function _getPendingRewards(address user, address reward, UserAssetBalance memory userAssetBalance)
        internal
        view
        returns (uint256)
    {
        RewardData storage localRewardData = _localAssetData[userAssetBalance.asset][reward];

        uint256 assetUnit;
        unchecked {
            assetUnit = 10 ** _REWARDS_CONTROLLER.getAssetDecimals(userAssetBalance.asset);
        }

        (, uint256 nextIndex) = _getAssetIndex(
            localRewardData, userAssetBalance.asset, reward, userAssetBalance.scaledTotalSupply, assetUnit
        );

        return
            _getRewards(userAssetBalance.scaledBalance, nextIndex, _computeUserIndex(localRewardData, user), assetUnit);
    }

    /// @dev Computes user's accrued rewards on a distribution.
    /// @param userBalance The current user asset balance.
    /// @param reserveIndex The current index of the distribution.
    /// @param userIndex The index stored for the user, representing its staking moment.
    /// @param assetUnit The asset's unit (10**decimals).
    /// @return rewards The rewards accrued.
    function _getRewards(uint256 userBalance, uint256 reserveIndex, uint256 userIndex, uint256 assetUnit)
        internal
        pure
        returns (uint256 rewards)
    {
        rewards = userBalance * (reserveIndex - userIndex);
        assembly {
            rewards := div(rewards, assetUnit)
        }
    }

    /// @dev Computes the next value of an specific distribution index, with validations.
    /// @param localRewardData The local reward's data.
    /// @param asset The asset being rewarded.
    /// @param reward The address of the reward token.
    /// @param scaledTotalSupply The current total supply of underlying assets for this distribution.
    /// @param assetUnit The asset's unit (10**decimals).
    /// @return The former index and the new index in this order.
    function _getAssetIndex(
        RewardData storage localRewardData,
        address asset,
        address reward,
        uint256 scaledTotalSupply,
        uint256 assetUnit
    ) internal view returns (uint256, uint256) {
        uint256 currentTimestamp = block.timestamp;

        if (currentTimestamp == localRewardData.lastUpdateTimestamp) {
            return (localRewardData.index, localRewardData.index);
        }

        (uint256 rewardIndex, uint256 emissionPerSecond, uint256 lastUpdateTimestamp, uint256 distributionEnd) =
            _REWARDS_CONTROLLER.getRewardsData(asset, reward);

        if (
            emissionPerSecond == 0 || scaledTotalSupply == 0 || lastUpdateTimestamp == currentTimestamp
                || lastUpdateTimestamp >= distributionEnd
        ) return (localRewardData.index, rewardIndex);

        currentTimestamp = currentTimestamp > distributionEnd ? distributionEnd : currentTimestamp;
        uint256 totalEmitted = emissionPerSecond * (currentTimestamp - lastUpdateTimestamp) * assetUnit;
        assembly {
            totalEmitted := div(totalEmitted, scaledTotalSupply)
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
                userAssetBalances[i].scaledBalance = _MORPHO.scaledPoolSupplyBalance(market.underlying, user)
                    + _MORPHO.scaledCollateralBalance(market.underlying, user);
            } else if (asset == market.variableDebtToken) {
                userAssetBalances[i].scaledBalance = _MORPHO.scaledPoolBorrowBalance(market.underlying, user);
            } else {
                revert InvalidAsset();
            }

            userAssetBalances[i].scaledTotalSupply = IScaledBalanceToken(asset).scaledTotalSupply();
        }
    }

    /// @dev Computes the index of a user for a specific reward distribution.
    /// @param localRewardData The local reward's data.
    /// @param user The address of the user.
    /// @return The index of the user for the distribution.
    function _computeUserIndex(RewardData storage localRewardData, address user) internal view returns (uint256) {
        uint256 index = uint256(localRewardData.usersData[user].index);
        return index == 0 ? localRewardData.startingIndex : index;
    }
}
