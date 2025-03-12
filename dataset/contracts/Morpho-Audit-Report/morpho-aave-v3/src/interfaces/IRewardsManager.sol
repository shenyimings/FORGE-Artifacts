// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IRewardsManager {
    /* STRUCTS */

    struct UserAssetBalance {
        address asset; // The rewarded asset (either aToken or debt token).
        uint256 scaledBalance; // The user scaled balance of this asset (in asset decimals).
        uint256 scaledTotalSupply; // The scaled total supply of this asset.
    }

    struct UserData {
        uint104 index; // The user's index for a specific (asset, reward) pair.
        uint128 accrued; // The user's accrued rewards for a specific (asset, reward) pair (in reward token decimals).
    }

    struct RewardData {
        uint104 startingIndex; // The index from which the RewardsManager begins tracking the RewardsController's index.
        uint104 index; // The current index for a specific reward token.
        uint32 lastUpdateTimestamp; // The last timestamp the index was updated.
        mapping(address => UserData) usersData; // Users data. user -> UserData
    }

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

    /* FUNCTIONS */

    function MORPHO() external view returns (address);
    function REWARDS_CONTROLLER() external view returns (address);

    function getRewardData(address asset, address reward)
        external
        view
        returns (uint256 startingIndex, uint256 index, uint256 lastUpdateTimestamp);
    function getUserData(address asset, address reward, address user)
        external
        view
        returns (uint256 index, uint256 accrued);

    function getAllUserRewards(address[] calldata assets, address user)
        external
        view
        returns (address[] memory rewardsList, uint256[] memory unclaimedAmounts);
    function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256);
    function getUserAccruedRewards(address[] calldata assets, address user, address reward)
        external
        view
        returns (uint256 totalAccrued);
    function getUserAssetIndex(address user, address asset, address reward) external view returns (uint256);
    function getAssetIndex(address asset, address reward) external view returns (uint256 assetIndex);

    function claimRewards(address[] calldata assets, address user)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
    function updateUserRewards(address user, address asset, uint256 userBalance) external;
}
