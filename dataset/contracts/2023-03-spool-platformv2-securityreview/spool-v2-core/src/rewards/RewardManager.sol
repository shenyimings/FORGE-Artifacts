// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/security/ReentrancyGuard.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IAssetGroupRegistry.sol";
import "../interfaces/IRewardManager.sol";
import "../interfaces/ISmartVault.sol";
import "../interfaces/ISmartVaultManager.sol";
import "../access/SpoolAccessControllable.sol";
import "../libraries/MathUtils.sol";
import "./RewardPool.sol";

contract RewardManager is IRewardManager, RewardPool, ReentrancyGuard {
    using SafeERC20 for IERC20;
    /* ========== CONSTANTS ========== */

    /// @notice Multiplier used when dealing reward calculations
    uint256 private constant REWARD_ACCURACY = 1e18;

    /* ========== STATE VARIABLES ========== */

    /// @notice Asset group registry
    IAssetGroupRegistry private _assetGroupRegistry;

    /// @notice Number of vault incentive tokens
    mapping(address => uint8) public rewardTokensCount;

    /// @notice All reward tokens supported by the contract
    mapping(address => mapping(uint256 => IERC20)) public rewardTokens;

    /// @notice Vault reward token incentive configuration
    mapping(address => mapping(IERC20 => RewardConfiguration)) public rewardConfiguration;

    mapping(address => mapping(IERC20 => bool)) tokenBlacklist;

    constructor(
        ISpoolAccessControl spoolAccessControl,
        IAssetGroupRegistry assetGroupRegistry_,
        bool allowPoolRootUpdates
    ) RewardPool(spoolAccessControl, allowPoolRootUpdates) {
        _assetGroupRegistry = assetGroupRegistry_;
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Blacklisted force-removed tokens
     */
    function tokenBlacklisted(address smartVault, IERC20 token) external view returns (bool) {
        return tokenBlacklist[smartVault][token];
    }

    function getRewardForDuration(address smartVault, IERC20 token) external view returns (uint256) {
        RewardConfiguration storage config = rewardConfiguration[smartVault][token];
        return uint256(config.rewardRate) * config.rewardsDuration;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * @notice Allows a new token to be added to the reward system
     *
     * @dev
     * Emits an {TokenAdded} event indicating the newly added reward token
     * and configuration
     *
     * Requirements:
     *
     * - the caller must be the reward distributor
     * - the reward duration must be non-zero
     * - the token must not have already been added
     *
     */
    function addToken(address smartVault, IERC20 token, uint32 rewardsDuration, uint256 reward)
        external
        onlyAdminOrVaultAdmin(smartVault, msg.sender)
        exceptUnderlying(smartVault, token)
    {
        RewardConfiguration storage config = rewardConfiguration[smartVault][token];

        if (tokenBlacklist[smartVault][token]) revert RewardTokenBlacklisted(address(token));
        if (config.tokenAdded != 0) revert RewardTokenAlreadyAdded(address(token));
        if (rewardsDuration == 0) revert InvalidRewardDuration();
        if (rewardTokensCount[smartVault] > 5) revert RewardTokenCapReached();

        rewardTokens[smartVault][rewardTokensCount[smartVault]] = token;
        rewardTokensCount[smartVault]++;

        config.rewardsDuration = rewardsDuration;

        if (reward > 0) {
            _extendRewardEmission(smartVault, token, reward);
        }
    }

    /**
     * @notice Extend reward emission
     */
    function extendRewardEmission(address smartVault, IERC20 token, uint256 reward, uint32 rewardsDuration)
        external
        onlyAdminOrVaultAdmin(smartVault, msg.sender)
        exceptUnderlying(smartVault, token)
    {
        if (tokenBlacklist[smartVault][token]) revert RewardTokenBlacklisted(address(token));
        if (rewardsDuration == 0) revert InvalidRewardDuration();
        if (rewardConfiguration[smartVault][token].tokenAdded == 0) {
            revert InvalidRewardToken(address(token));
        }

        rewardConfiguration[smartVault][token].rewardsDuration = rewardsDuration;
        _extendRewardEmission(smartVault, token, reward);
    }

    function _extendRewardEmission(address smartVault, IERC20 token, uint256 reward) private {
        RewardConfiguration storage config = rewardConfiguration[smartVault][token];

        token.safeTransferFrom(msg.sender, address(this), reward);
        uint32 newPeriodFinish = uint32(block.timestamp) + config.rewardsDuration;

        if (block.timestamp >= config.periodFinish) {
            config.rewardRate = SafeCast.toUint192((reward * REWARD_ACCURACY) / config.rewardsDuration);
            emit RewardAdded(smartVault, token, reward, config.rewardsDuration);
        } else {
            // If extending or adding additional rewards,
            // cannot set new finish time to be less than previously configured
            if (config.periodFinish > newPeriodFinish) {
                revert NewPeriodFinishLessThanBefore();
            }
            uint256 remaining = config.periodFinish - block.timestamp;
            uint256 leftover = remaining * config.rewardRate;
            uint192 newRewardRate = SafeCast.toUint192((reward * REWARD_ACCURACY + leftover) / config.rewardsDuration);
            if (newRewardRate < config.rewardRate) {
                revert NewRewardRateLessThanBefore();
            }

            config.rewardRate = newRewardRate;
            emit RewardExtended(smartVault, token, reward, leftover, config.rewardsDuration, newPeriodFinish);
        }

        config.tokenAdded = uint32(block.timestamp);
        config.periodFinish = newPeriodFinish;
    }

    /**
     * @notice Force remove reward from vault rewards configuration.
     * @dev This is meant to be an emergency function if a reward token breaks.
     *
     * Requirements:
     * - the caller must be SPOOL ADMIN
     *
     * @param token Token address to remove
     */
    function forceRemoveReward(address smartVault, IERC20 token) external onlyRole(ROLE_SPOOL_ADMIN, msg.sender) {
        tokenBlacklist[smartVault][token] = true;
        _removeReward(smartVault, token);

        delete rewardConfiguration[smartVault][token];
    }

    /**
     * @notice Remove reward from vault rewards configuration.
     * @dev
     * Used to sanitize vault and save on gas, after the reward has ended.
     * Users will be able to claim rewards
     *
     * Requirements:
     *
     * - the caller must be the spool owner or Spool DAO
     * - cannot claim vault underlying token
     * - cannot only execute if the reward finished
     *
     * @param token Token address to remove
     */
    function removeReward(address smartVault, IERC20 token)
        external
        onlyAdminOrVaultAdmin(smartVault, msg.sender)
        onlyFinished(smartVault, token)
    {
        _removeReward(smartVault, token);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _removeReward(address smartVault, IERC20 token) private {
        uint256 _rewardTokensCount = rewardTokensCount[smartVault];
        for (uint256 i; i < _rewardTokensCount; ++i) {
            if (rewardTokens[smartVault][i] == token) {
                rewardTokens[smartVault][i] = rewardTokens[smartVault][_rewardTokensCount - 1];

                delete rewardTokens[smartVault][_rewardTokensCount- 1];
                rewardTokensCount[smartVault]--;
                emit RewardRemoved(smartVault, token);

                break;
            }
        }
    }

    function _exceptUnderlying(address smartVault, IERC20 token) private view {
        address[] memory vaultTokens = _assetGroupRegistry.listAssetGroup(ISmartVault(smartVault).assetGroupId());
        for (uint256 i; i < vaultTokens.length; ++i) {
            if (vaultTokens[i] == address(token)) {
                revert AssetGroupToken(address(token));
            }
        }
    }

    function _onlyFinished(address smartVault, IERC20 token) private view {
        if (block.timestamp <= rewardConfiguration[smartVault][token].periodFinish) {
            revert RewardsNotFinished();
        }
    }

    /* ========== MODIFIERS ========== */

    modifier exceptUnderlying(address smartVault, IERC20 token) {
        _exceptUnderlying(smartVault, token);
        _;
    }

    modifier onlyFinished(address smartVault, IERC20 token) {
        _onlyFinished(smartVault, token);
        _;
    }
}
