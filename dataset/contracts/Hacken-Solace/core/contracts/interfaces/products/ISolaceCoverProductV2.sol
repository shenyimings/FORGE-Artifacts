// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

interface ISolaceCoverProductV2 {
    /***************************************
    EVENTS
    ***************************************/

    /// @notice Emitted when a new Policy is created.
    event PolicyCreated(uint256 policyID);

    /// @notice Emitted when a Policy is updated.
    event PolicyUpdated(uint256 policyID);

    /// @notice Emitted when a Policy is deactivated.
    event PolicyDeactivated(uint256 policyID);

    /// @notice Emitted when Registry address is updated.
    event RegistrySet(address registry);

    /// @notice Emitted when pause is set.
    event PauseSet(bool pause);

    /// @notice Emitted when a user enters cooldown mode.
    event CooldownStarted(address policyholder, uint256 startTime);

    /// @notice Emitted when a user leaves cooldown mode.
    event CooldownStopped(address policyholder);

    /// @notice Emitted when the cooldown period is set.
    event CooldownPeriodSet(uint256 cooldownPeriod);

    /// @notice Emitted when a deposit is made.
    event DepositMade(
        address from,
        address policyholder,
        uint256 amount
    );

    /// @notice Emitted when a withdraw is made.
    event WithdrawMade(address policyholder, uint256 amount);

    /// @notice Emitted when premium is charged.
    event PremiumCharged(address policyholder, uint256 amount);

    /// @notice Emitted when premium is partially charged.
    event PremiumPartiallyCharged(
        address policyholder,
        uint256 actualPremium,
        uint256 chargedPremium
    );

    /// @notice Emitted when policy manager cover amount for soteria is updated.
    event PolicyManagerUpdated(uint256 activeCoverLimit);

    /// @notice Emitted when maxRate is set.
    event MaxRateSet(uint256 maxRateNum, uint256 maxRateDenom);

    /// @notice Emitted when chargeCycle is set.
    event ChargeCycleSet(uint256 chargeCycle);

    /// @notice Emitted when reward points are set.
    event RewardPointsSet(address policyholder, uint256 amountGifted);

    /// @notice Emitted when isReferralOn is set
    event IsReferralOnSet(bool isReferralOn);

    /// @notice Emitted when referralReward is set.
    event ReferralRewardSet(uint256 referralReward);

    /// @notice Emitted when referralThreshold is set.
    event ReferralThresholdSet(uint256 referralThreshold);

    /// @notice Emitted when referral rewards are earned;
    event ReferralRewardsEarned(
        address rewardEarner,
        uint256 rewardPointsEarned
    );

    /// @notice Emitted when baseURI is set
    event BaseURISet(string baseURI);

    /// @notice Emitted when supported chain is set.
    event SupportedChainSet(uint256 chainId);

    /// @notice Emitted when supported chain is removed.
    event SupportedChainRemoved(uint256 chainId);

    /// @notice Emiited when asset is set.
    event AssetSet(string asset);

    /***************************************
    POLICY FUNCTIONS
    ***************************************/

    /**
     * @notice Activates policy for `policyholder_`
     * @param policyholder_ The address of the intended policyholder.
     * @param coverLimit_ The maximum value to cover in **USD**.
     * @param amount_ The deposit amount in **USD** to fund the policyholder's account.
     * @param referralCode_ The referral code.
     * @param chains_ The chain ids.
     * @return policyID The ID of the newly minted policy.
     */
    function activatePolicy(
        address policyholder_,
        uint256 coverLimit_,
        uint256 amount_,
        bytes calldata referralCode_,
        uint256[] calldata chains_
    ) external returns (uint256 policyID);

    /**
     * @notice Updates the cover limit of a user's policy.
     *
     * This will reset the cooldown.
     * @param newCoverLimit_ The new maximum value to cover in **USD**.
     * @param referralCode_ The referral code.
     */
    function updateCoverLimit(
        uint256 newCoverLimit_,
        bytes calldata referralCode_
    ) external;

    /**
     * @notice Updates policy chain info.
     * @param policyChains The requested policy chains to update.
    */
    function updatePolicyChainInfo(uint256[] memory policyChains) external;

    /**
     * @notice Deposits funds into `policyholder`'s account.
     * @param policyholder The policyholder.
     * @param amount The amount to deposit in **USD**.
     */
    function deposit(
        address policyholder,
        uint256 amount
    ) external;


    /**
     * @notice Withdraw funds from user's account.
     *
     * @notice If cooldown has passed, the user will withdraw their entire account balance.
     * @notice If cooldown has not started, or has not passed, the user will not be able to withdraw their entire account.
     * @notice If cooldown has not passed, [`withdraw()`](#withdraw) will leave a minimum required account balance (one epoch's fee) in the user's account.
     */
    function withdraw() external;

    /**
     * @notice Deactivate a user's policy.
     *
     * This will set a user's cover limit to 0, and begin the cooldown timer. Read comments for [`withdraw()`](#withdraw) for cooldown mechanic details.
     */
    function deactivatePolicy() external;

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Returns the policyholder's account account balance in **USD**.
     * @param policyholder The policyholder address.
     * @return balance The policyholder's account balance in **USD**.
     */
    function accountBalanceOf(address policyholder) external view returns (uint256 balance);

    /**
     * @notice The maximum amount of cover that can be sold in **USD** to 18 decimals places.
     * @return cover The max amount of cover.
     */
    function maxCover() external view returns (uint256 cover);

    /**
     * @notice Returns the active cover limit in **USD** to 18 decimal places. In other words, the total cover that has been sold at the current time.
     * @return amount The active cover limit.
     */
    function activeCoverLimit() external view returns (uint256 amount);

    /**
     * @notice Determine the available remaining capacity for new cover.
     * @return availableCoverCapacity_ The amount of available remaining capacity for new cover.
     */
    function availableCoverCapacity() external view returns (uint256 availableCoverCapacity_);

    /**
     * @notice Get the reward points that a policyholder has in **USD** to 18 decimal places.
     * @param policyholder_ The policyholder address.
     * @return rewardPoints_ The reward points for the policyholder.
     */
    function rewardPointsOf(address policyholder_) external view returns (uint256 rewardPoints_);

    /**
     * @notice Get the total premium that a policyholder has in **USD** to 18 decimal places (does not include premium paid through reward points)
     * @param policyholder_ The policyholder address.
     * @return premiumsPaid_ The total premium paid for the policyholder.
     */
    function premiumsPaidOf(address policyholder_) external view returns (uint256 premiumsPaid_);

    /**
     * @notice Gets the policyholder's policy ID.
     * @param policyholder_ The address of the policyholder.
     * @return policyID The policy ID.
     */
    function policyOf(address policyholder_) external view returns (uint256 policyID);

    /**
     * @notice Returns true if the policy is active, false if inactive
     * @param policyID_ The policy ID.
     * @return status True if policy is active. False otherwise.
     */
    function policyStatus(uint256 policyID_) external view returns (bool status);

    /**
     * @notice Returns  [`Registry`](./Registry) contract address.
     * @return registry_ The `Registry` address.
     */
    function registry() external view returns (address registry_);

    /**
     * @notice Returns [`RiskManager`](./RiskManager) contract address.
     * @return riskManager_ The `RiskManager` address.
     */
    function riskManager() external view returns (address riskManager_);

    /**
     * @notice Returns true if the product is paused, false if not.
     * @return status True if product is paused.
     */
    function paused() external view returns (bool status);

    /**
     * @notice Gets the policy count (amount of policies that have been purchased, includes inactive policies).
     * @return count The policy count.
     */
    function policyCount() external view returns (uint256 count);

    /**
     * @notice Returns the max rate.
     * @return maxRateNum_ the max rate numerator.
     * @return maxRateDenom_ the max rate denominator.
     */
    function maxRate() external view returns (uint256 maxRateNum_, uint256 maxRateDenom_);

    /**
     * @notice Gets the charge cycle duration.
     * @return chargeCycle_ the charge cycle duration in seconds.
     */
    function chargeCycle() external view returns (uint256 chargeCycle_);

    /**
     * @notice Gets cover limit for a given policy ID.
     * @param policyID_ The policy ID.
     * @return amount The cover limit for given policy ID.
     */
    function coverLimitOf(uint256 policyID_) external view returns (uint256 amount);

    /**
     * @notice Gets the cooldown period.
     *
     * Cooldown timer is started by the user calling deactivatePolicy().
     * Before the cooldown has started or has passed, withdrawing funds will leave a minimim required account balance in the user's account.
     * Only after the cooldown has passed, is a user able to withdraw their entire account balance.
     * @return cooldownPeriod_ The cooldown period in seconds.
     */
    function cooldownPeriod() external view returns (uint256 cooldownPeriod_);

    /**
     * @notice The Unix timestamp that a policyholder's cooldown started. If cooldown has not started or has been reset, will return 0.
     * @param policyholder_ The policyholder address
     * @return cooldownStart_ The cooldown period start expressed as Unix timestamp
     */
    function cooldownStart(address policyholder_) external view returns (uint256 cooldownStart_);

    /**
     * @notice Gets the referral reward
     * @return referralReward_ The referral reward
     */
    function referralReward() external view returns (uint256 referralReward_);

    /**
     * @notice Gets the threshold premium amount in USD that an account needs to have paid, for the account to be able to apply a referral code
     * @return referralThreshold_ The referral threshold
     */
    function referralThreshold() external view returns (uint256 referralThreshold_);

    /**
     * @notice Returns true if referral rewards are active, false if not.
     * @return isReferralOn_ True if referral rewards are active, false if not.
     */
    function isReferralOn() external view returns (bool isReferralOn_);

    /**
     * @notice True if a policyholder has previously used a valid referral code, false if not
     *
     * A policyholder can only use a referral code once. Afterwards a policyholder is ineligible to receive further rewards from additional referral codes.
     * @return isReferralCodeUsed_ True if the policyholder has previously used a valid referral code, false if not
     */
    function isReferralCodeUsed(address policyholder) external view returns (bool isReferralCodeUsed_);

    /**
     * @notice Returns true if valid referral code, false otherwise.
     * @param referralCode The referral code.
     */
    function isReferralCodeValid(bytes calldata referralCode) external view returns (bool);

    /**
     * @notice Get referrer from referral code, returns 0 address if invalid referral code.
     * @param referralCode The referral code.
     * @return referrer The referrer address, returns 0 address if invalid referral code.
     */
    function getReferrerFromReferralCode(bytes calldata referralCode) external view returns (address referrer);

    /**
     * @notice Calculate minimum required account balance for a given cover limit. Equals the maximum chargeable fee for one epoch.
     * @param coverLimit Cover limit.
     */
    function minRequiredAccountBalance(uint256 coverLimit) external view returns (uint256 minRequiredAccountBalance_);

    /**
     * @notice Returns true if given chain id supported.
     * @return status True if chain is supported otherwise false.
    */
    function isSupportedChain(uint256 chainId) external view returns (bool status);

    /**
     * @notice Returns the number of chains.
     * @return count The number of chains.
     */
    function numSupportedChains() external view returns (uint256 count);

    /**
     * @notice Returns the chain at the given index.
     * @param chainIndex The index to query.
     * @return chainId The address of the chain.
     */
    function getChain(uint256 chainIndex) external view returns (uint256 chainId);

    /**
     * @notice Returns the policy chain info.
     * @param policyID The policy id to get chain info.
     * @return policyChains The list of policy chain values.
    */
    function getPolicyChainInfo(uint256 policyID) external view returns (uint256[] memory policyChains);

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Sets the [`Registry`](./Registry) contract address.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param registry_ The address of `Registry` contract.
     */
    function setRegistry(address registry_) external;

    /**
     * @notice Pauses or unpauses policies.
     * Deactivating policies are unaffected by pause.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param paused_ True to pause, false to unpause.
     */
    function setPaused(bool paused_) external;

    /**
     * @notice Sets the cooldown period. Read comments for [`cooldownPeriod()`](#cooldownPeriod) for more information on the cooldown mechanic.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param cooldownPeriod_ Cooldown period in seconds.
     */
    function setCooldownPeriod(uint256 cooldownPeriod_) external;

    /**
     * @notice set _maxRate.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param maxRateNum_ Desired maxRateNum.
     * @param maxRateDenom_ Desired maxRateDenom.
     */
    function setMaxRate(uint256 maxRateNum_, uint256 maxRateDenom_) external;

    /**
     * @notice set _chargeCycle.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param chargeCycle_ Desired chargeCycle.
     */
    function setChargeCycle(uint256 chargeCycle_) external;

    /**
     * @notice set _referralReward
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param referralReward_ Desired referralReward.
    */
    function setReferralReward(uint256 referralReward_) external;

    /**
     * @notice set _referralThreshhold
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param referralThreshhold_ Desired referralThreshhold.
    */
    function setReferralThreshold(uint256 referralThreshhold_) external;

    /**
     * @notice set _isReferralOn
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param isReferralOn_ Desired state of referral campaign.
    */
    function setIsReferralOn(bool isReferralOn_) external;

    /**
     * @notice Sets the base URI for computing `tokenURI`.
     * @param baseURI_ The new base URI.
     */
    function setBaseURI(string memory baseURI_) external;

    /**
     * @notice Adds supported chains to cover positions.
     * @param chains The supported array of chains.
    */
    function addSupportedChains(uint256[] memory chains) external;

    /**
     * @notice Removes chain from the supported chain list.
     * @param chainId The chain id to remove.
    */
    function removeSupportedChain(uint256 chainId) external;

    /**
     * @notice Sets the asset name.
     * @param assetName The asset name to set.
    */
    function setAsset(string memory assetName) external;

    /***************************************
    COVER PROMOTION ADMIN FUNCTIONS
    ***************************************/

    /**
     * @notice Enables cover promotion admin to set reward points for a selected address.
     *
     * Can only be called by the **Cover Promotion Admin** role.
     * @param policyholder_ The address of the policyholder to set reward points for.
     * @param rewardPoints_ Desired amount of reward points.
     */
    function setRewardPoints(
        address policyholder_,
        uint256 rewardPoints_
    ) external;

    /***************************************
    PREMIUM COLLECTOR FUNCTIONS
    ***************************************/

    /**
     * @notice Charge premiums for each policy holder.
     *
     * Can only be called by the **Premium Collector** role.
     * @dev Cheaper to load variables directly from calldata, rather than adding an additional operation of copying to memory.
     * @param holders Array of addresses of the policyholders to charge.
     * @param premiums Array of premium amounts (in **USD** to 18 decimal places) to charge each policyholder.
     */
    function chargePremiums(
        address[] calldata holders,
        uint256[] calldata premiums
    ) external;
}
