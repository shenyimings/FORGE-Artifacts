// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;


/**
 * @title IRiskManager
 * @author solace.fi
 * @notice Calculates the acceptable risk, sellable cover, and capital requirements of Solace products and capital pool.
 *
 * The total amount of sellable coverage is proportional to the assets in the [**risk backing capital pool**](../Vault). The max cover is split amongst products in a weighting system. [**Governance**](/docs/protocol/governance). can change these weights and with it each product's sellable cover.
 *
 * The minimum capital requirement is proportional to the amount of cover sold to [active policies](../PolicyManager).
 *
 * Solace can use leverage to sell more cover than the available capital. The amount of leverage is stored as [`partialReservesFactor`](#partialreservesfactor) and is settable by [**governance**](/docs/protocol/governance).
 */
interface IRiskManager {

    /***************************************
    TYPE DEFINITIONS
    ***************************************/

    enum StrategyStatus {
       INACTIVE,
       ACTIVE
    }

    struct Strategy {
        uint256 id;
        uint32 weight;
        StrategyStatus status;
        uint256 timestamp;
    }

    /***************************************
    EVENTS
    ***************************************/

    /// @notice Emitted when new strategy is created.
    event StrategyAdded(address strategy);

    /// @notice Emitted when strategy status is updated.
    event StrategyStatusUpdated(address strategy, uint8 status);

    /// @notice Emitted when strategy's allocation weight is increased.
    event RiskStrategyWeightAllocationIncreased(address strategy, uint32 weight);

    /// @notice Emitted when strategy's allocation weight is decreased.
    event RiskStrategyWeightAllocationDecreased(address strategy, uint32 weight);

    /// @notice Emitted when strategy's allocation weight is set.
    event RiskStrategyWeightAllocationSet(address strategy, uint32 weight);

    /// @notice Emitted when the partial reserves factor is set.
    event PartialReservesFactorSet(uint16 partialReservesFactor);

    /// @notice Emitted when the cover limit amount of the strategy is updated.
    event ActiveCoverLimitUpdated(address strategy, uint256 oldCoverLimit, uint256 newCoverLimit);

    /// @notice Emitted when the cover limit updater is set.
    event CoverLimitUpdaterAdded(address updater);

    /// @notice Emitted when the cover limit updater is removed.
    event CoverLimitUpdaterDeleted(address updater);

    /***************************************
    RISK MANAGER MUTUTATOR FUNCTIONS
    ***************************************/

    /**
     * @notice Adds a new `Risk Strategy` to the `Risk Manager`. The community votes the strategy for coverage weight allocation.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param strategy_ The address of the risk strategy.
     * @return index The index of the risk strategy.
    */
    function addRiskStrategy(address strategy_) external returns (uint256 index);

    /**
     * @notice Sets the weight of the `Risk Strategy`.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param strategy_ The address of the risk strategy.
     * @param weight_ The value to set.
    */
    function setWeightAllocation(address strategy_, uint32 weight_) external;

    /**
     * @notice Sets the status of the `Risk Strategy`.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param strategy_ The address of the risk strategy.
     * @param status_ The status to set.
    */
    function setStrategyStatus(address strategy_, uint8 status_) external;

   /**
     * @notice Updates the active cover limit amount for the given strategy. 
     * This function is only called by valid requesters when a new policy is bought or updated.
     * @dev The policy manager and soteria will call this function for now.
     * @param strategy The strategy address to add cover limit.
     * @param currentCoverLimit The current cover limit amount of the strategy's product.
     * @param newCoverLimit The new cover limit amount of the strategy's product.
    */
    function updateActiveCoverLimitForStrategy(address strategy, uint256 currentCoverLimit, uint256 newCoverLimit) external;

    /**
     * @notice Adds new address to allow updating cover limit amounts.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param updater The address that can update cover limit.
    */
    function addCoverLimitUpdater(address updater) external ;

    /**
     * @notice Removes the cover limit updater.
     * @param updater The address of updater to remove.
    */
    function removeCoverLimitUpdater(address updater) external;

    /***************************************
    RISK MANAGER VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Checks is an address is an active strategy.
     * @param strategy_ The risk strategy.
     * @return status True if the strategy is active.
    */
    function strategyIsActive(address strategy_) external view returns (bool status);

     /**
      * @notice Return the strategy at an index.
      * @dev Enumerable `[1, numStrategies]`.
      * @param index_ Index to query.
      * @return strategy The product address.
    */
    function strategyAt(uint256 index_) external view returns (address strategy);

    /**
     * @notice Returns the number of registered strategies..
     * @return count The number of strategies.
    */
    function numStrategies() external view returns (uint256 count);

    /**
     * @notice Returns the risk strategy information.
     * @param strategy_ The risk strategy.
     * @return id The id of the risk strategy.
     * @return weight The risk strategy weight allocation.
     * @return status The status of risk strategy.
     * @return timestamp The added time of the risk strategy.
     *
    */
    function strategyInfo(address strategy_) external view returns (uint256 id, uint32 weight, StrategyStatus status, uint256 timestamp);

    /**
     * @notice Returns the allocated weight for the risk strategy.
     * @param strategy_ The risk strategy.
     * @return weight The risk strategy weight allocation.
    */
    function weightPerStrategy(address strategy_) external view returns (uint32 weight);

    /**
     * @notice The maximum amount of cover for given strategy can sell.
     * @return cover The max amount of cover in wei.
     */
    function maxCoverPerStrategy(address strategy_) external view returns (uint256 cover);

    /**
     * @notice Returns the current amount covered (in wei).
     * @return amount The covered amount (in wei).
    */
    function activeCoverLimit() external view returns (uint256 amount);

    /**
     * @notice Returns the current amount covered (in wei).
     * @param riskStrategy The risk strategy address.
     * @return amount The covered amount (in wei).
    */
    function activeCoverLimitPerStrategy(address riskStrategy) external view returns (uint256 amount);

    /***************************************
    MAX COVER VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice The maximum amount of cover that Solace as a whole can sell.
     * @return cover The max amount of cover in wei.
     */
    function maxCover() external view returns (uint256 cover);

    /**
     * @notice Returns the sum of allocation weights for all strategies.
     * @return sum WeightSum.
     */
    function weightSum() external view returns (uint32 sum);

    /***************************************
    MIN CAPITAL VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice The minimum amount of capital required to safely cover all policies.
     * @return mcr The minimum capital requirement.
     */
    function minCapitalRequirement() external view returns (uint256 mcr);

    /**
     * @notice The minimum amount of capital required to safely cover all policies.
     * @param strategy_ The risk strategy.
     * @return mcr The minimum capital requirement.
     */
    function minCapitalRequirementPerStrategy(address strategy_) external view returns (uint256 mcr);

    /**
     * @notice Multiplier for minimum capital requirement.
     * @return factor Partial reserves factor in BPS.
     */
    function partialReservesFactor() external view returns (uint16 factor);

    /**
     * @notice Sets the partial reserves factor.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param partialReservesFactor_ New partial reserves factor in BPS.
     */
    function setPartialReservesFactor(uint16 partialReservesFactor_) external;
}