// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

/**
 * @title IProduct
 * @author solace.fi
 * @notice Interface for product contracts
 */
interface IProduct {

    /***************************************
    EVENTS
    ***************************************/

    /// @notice Emitted when a policy is created.
    event PolicyCreated(uint256 indexed policyID);
    /// @notice Emitted when a policy is extended.
    event PolicyExtended(uint256 indexed policyID);
    /// @notice Emitted when a policy is canceled.
    event PolicyCanceled(uint256 indexed policyID);
    /// @notice Emitted when a policy is updated.
    event PolicyUpdated(uint256 indexed policyID);
    /// @notice Emitted when a claim is submitted.
    event ClaimSubmitted(uint256 indexed policyID);
    /// @notice Emitted when min period is set.
    event MinPeriodSet(uint40 minPeriod);
    /// @notice Emitted when max period is set.
    event MaxPeriodSet(uint40 maxPeriod);
    /// @notice Emitted when buying is paused or unpaused.
    event PauseSet(bool paused);
    /// @notice Emitted when PolicyManager is set.
    event PolicyManagerSet(address policyManager);
    /// @notice Emitted when Deposit into premium pool is made
    event DepositMade(uint256 depositAmount); 
    /// @notice Emitted when withdraw from premium pool is made
    event WithdrawMade(uint256 withdrawAmount); 

    /***************************************
    POLICYHOLDER FUNCTIONS
    ***************************************/

    /**
     * @notice Purchases and mints a policy on the behalf of the policyholder.
     * User will need to pay **USD**.
     * @param policyholder Holder of the position(s) to cover.
     * @param coverLimit The value to cover in **USD**.
     * @param blocks The length (in blocks) for policy.
     * @param positionDescription A byte encoded description of the position(s) to cover.
     * @param riskStrategy The risk strategy of the product to cover.
     * @return policyID The ID of newly created policy.
     */
    function buyPolicy(address policyholder, uint256 coverLimit, uint40 blocks, bytes memory positionDescription, address riskStrategy) external returns (uint256 policyID);

    /**
     * @notice Increase or decrease the cover limit of the policy.
     * User may need to pay **USD** for increased cover limit or receive a refund for decreased cover limit.
     * Can only be called by the policyholder.
     * @param policyID The ID of the policy.
     * @param newCoverLimit The new value to cover in **USD**.
     */
    function updateCoverLimit(uint256 policyID, uint256 newCoverLimit) external;

    /**
     * @notice Extend a policy.
     * User will need to pay **USD**.
     * Can only be called by the policyholder.
     * @param policyID The ID of the policy.
     * @param extension The length of extension in blocks.
     */
    function extendPolicy(uint256 policyID, uint40 extension) external;

    /**
     * @notice Extend a policy and update its cover limit.
     * User may need to pay **USD** for increased cover limit or receive a refund for decreased cover limit.
     * Can only be called by the policyholder.
     * @param policyID The ID of the policy.
     * @param newCoverLimit The new value to cover in **USD**.
     * @param extension The length of extension in blocks.
     */
    function updatePolicy(uint256 policyID, uint256 newCoverLimit, uint40 extension) external;

    /**
     * @notice Cancel and burn a policy.
     * User will receive a refund for the remaining blocks.
     * Can only be called by the policyholder.
     * @param policyID The ID of the policy.
     */
    function cancelPolicy(uint256 policyID) external;

    /***************************************
    QUOTE VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Calculate a premium quote for a policy.
     * @param coverLimit The value to cover in **USD**.
     * @param blocks The duration of the policy in blocks.
     * @param riskStrategy The risk strategy address.
     * @return premium The quote for their policy in **USD**.
     */
    function getQuote(uint256 coverLimit, uint40 blocks, address riskStrategy) external view returns (uint256 premium);

    /***************************************
    GLOBAL VIEW FUNCTIONS
    ***************************************/

    /** 
     * @notice Returns the minimum policy period in blocks.
     * @return period The minimum period value.
    */
    function minPeriod() external view returns (uint40);

    /**
     * @notice Returns the maximum policy period in blocks.
     * @return period The maxiumum period value.
    */
    function maxPeriod() external view returns (uint40);

    /**
     * @notice Returns the current amount covered (in wei).
     * @return amount The current amount.
    */
    function activeCoverLimit() external view returns (uint256 amount);

    /**
     * @notice Returns the current amount covered (in wei) per risk strategy.
     * @param riskStrategy The risk strategy address.
     * @return amount The current amount.
    */
    function activeCoverLimitPerStrategy(address riskStrategy) external view returns (uint256 amount);

    /**
     * @notice Returns whether or not product is currently in paused state.
     * @return status True if product is paused.
    */
    function paused() external view returns (bool status);

    /**
     * @notice Returns the address of the [`PolicyManager`](../PolicyManager).
     * @return policymanager The policy manager address.
    */
    function policyManager() external view returns (address policymanager);

    /**
     * @notice Returns the address of the [`Registry`](../Registry).
     * @return registry The registry address.
    */
    function registry() external view returns (address registry);
   
    /**
     * @notice Returns true if the given account is authorized to sign claims.
     * @param account Potential signer to query.
     * @return status True if is authorized signer.
     */
     function isAuthorizedSigner(address account) external view returns (bool status);

    /***************************************
    MUTATOR FUNCTIONS
    ***************************************/

    /**
     * @notice Updates the product's book-keeping variables.
     * Can only be called by the [`PolicyManager`](../PolicyManager).
     * @param coverDiff The change in active cover limit.
     */
    function updateActiveCoverLimit(int256 coverDiff) external;

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Sets the minimum number of blocks a policy can be purchased for.
     * @param minPeriod_ The minimum number of blocks.
     */
    function setMinPeriod(uint40 minPeriod_) external;

    /**
     * @notice Sets the maximum number of blocks a policy can be purchased for.
     * @param maxPeriod_ The maximum number of blocks
     */
    function setMaxPeriod(uint40 maxPeriod_) external;
}
