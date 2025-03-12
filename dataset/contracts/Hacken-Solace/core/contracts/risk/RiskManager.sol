// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "../utils/Governable.sol";
import "../interfaces/risk/ICoverageDataProvider.sol";
import "../interfaces/utils/IRegistry.sol";
import "../interfaces/risk/IRiskManager.sol";

/**
 * @title RiskManager
 * @author solace.fi
 * @notice Calculates the acceptable risk, sellable cover, and capital requirements of Solace products and capital pool.
 *
 * The total amount of sellable coverage is proportional to the assets in the [**risk backing capital pool**](./Vault). The max cover is split amongst products in a weighting system. [**Governance**](/docs/protocol/governance) can change these weights and with it each product's sellable cover.
 *
 * The minimum capital requirement is proportional to the amount of cover sold to active policies.
 *
 * Solace can use leverage to sell more cover than the available capital. The amount of leverage is stored as [`partialReservesFactor`](#partialreservesfactor) and is settable by [**governance**](/docs/protocol/governance).
 */
contract RiskManager is IRiskManager, Governable {

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice Holds mapping strategy => inddex.
    mapping(address => uint256) private _strategyToIndex;
    /// @notice Holds mapping index => strategy.
    mapping(uint256 => address) private _indexToStrategy;
    /// @notice Holds strategies.
    mapping(address => Strategy) private _strategies;
    /// @notice Returns true if the caller valid cover limit updater.
    mapping(address => bool) public canUpdateCoverLimit;
    // The current amount covered (in wei).
    uint256 internal _activeCoverLimit;
    /// @notice The current amount covered (in wei) per strategy;
    mapping(address => uint256) internal _activeCoverLimitPerStrategy;
    /// @notice The total strategy count.
    uint256 private _strategyCount;
    /// @notice The total weight sum of all strategies.
    uint32 private _weightSum;
    /// @notice Multiplier for minimum capital requirement in BPS.
    uint16 private _partialReservesFactor;
    /// @notice 10k basis points (100%).
    uint16 private constant MAX_BPS = 10000;

    /// @notice Registry contract.
    IRegistry private _registry;

    /**
     * @notice Constructs the RiskManager contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     * @param registry_ Address of registry.
     */
    constructor(address governance_, address registry_) Governable(governance_) {
        require(registry_ != address(0x0), "zero address registry");
        _registry = IRegistry(registry_);
        _partialReservesFactor = MAX_BPS;
    }

    /***************************************
    RISK MANAGER MUTUATOR FUNCTIONS
    ***************************************/

    /**
     * @notice Adds a new `Risk Strategy` to the `Risk Manager`. The community votes the strategy for coverage weight allocation.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param strategy_ The address of the risk strategy.
     * @return index The index of the risk strategy.
    */
    function addRiskStrategy(address strategy_) external override onlyGovernance returns (uint256 index) {
        require(strategy_ != address(0x0), "zero address strategy");
        require(_strategyToIndex[strategy_] == 0, "duplicate strategy");

        uint256 strategyCount = _strategyCount;
        _strategies[strategy_] = Strategy({
            id: ++strategyCount,
            weight: 0,
            status: StrategyStatus.INACTIVE,
            timestamp: block.timestamp
        });
        _strategyToIndex[strategy_] = strategyCount;
        _indexToStrategy[strategyCount] = strategy_;
        _strategyCount = strategyCount;
        emit StrategyAdded(strategy_);
        return strategyCount;
    }

    /**
     * @notice Sets the weight of the `Risk Strategy`.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param strategy_ The address of the risk strategy.
     * @param weight_ The value to set.
    */
    function setWeightAllocation(address strategy_, uint32 weight_) external override onlyGovernance {
        require(weight_ > 0, "invalid weight!");
        require(strategyIsActive(strategy_), "inactive strategy");
        require(validateAllocation(strategy_, weight_), "invalid weight allocation");
        Strategy storage riskStrategy = _strategies[strategy_];
        _weightSum = (_weightSum + weight_) - riskStrategy.weight;
        riskStrategy.weight = weight_;
        emit RiskStrategyWeightAllocationSet(strategy_, weight_);
    }

    /**
     * @notice Sets the status of the `Risk Strategy`.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param strategy_ The address of the risk strategy.
     * @param status_ The status to set.
    */
    function setStrategyStatus(address strategy_, uint8 status_) public override onlyGovernance {
        require(strategy_ != address(0x0), "zero address strategy");
        require(_strategyToIndex[strategy_] > 0, "non-exist strategy");
        Strategy storage riskStrategy = _strategies[strategy_];
        riskStrategy.status = StrategyStatus(status_);
        emit StrategyStatusUpdated(strategy_, status_);
    }

   /**
     * @notice Updates the active cover limit amount for the given strategy. 
     * This function is only called by valid requesters when a new policy is bought or updated.
     * @dev The policy manager and soteria will call this function for now.
     * @param strategy The strategy address to add cover limit.
     * @param currentCoverLimit The current cover limit amount of the strategy's product.
     * @param newCoverLimit The new cover limit amount of the strategy's product.
    */
    function updateActiveCoverLimitForStrategy(address strategy, uint256 currentCoverLimit, uint256 newCoverLimit) external override {
        require(canUpdateCoverLimit[msg.sender], "unauthorized caller");
        require(strategyIsActive(strategy), "inactive strategy");
        uint256 oldCoverLimitOfStrategy = _activeCoverLimitPerStrategy[strategy];
        _activeCoverLimit = _activeCoverLimit - currentCoverLimit + newCoverLimit;
        uint256 newCoverLimitOfStrategy = oldCoverLimitOfStrategy - currentCoverLimit + newCoverLimit;
        _activeCoverLimitPerStrategy[strategy] = newCoverLimitOfStrategy;
        emit ActiveCoverLimitUpdated(strategy, oldCoverLimitOfStrategy, newCoverLimitOfStrategy);
    }

    /**
     * @notice Adds new address to allow updating cover limit amounts.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param updater The address that can update cover limit.
    */
    function addCoverLimitUpdater(address updater) external override onlyGovernance {
        require(updater != address(0x0), "zero address coverlimit updater");
        canUpdateCoverLimit[updater] = true;
        emit CoverLimitUpdaterAdded(updater);
    }

    /**
     * @notice Removes the cover limit updater.
     * @param updater The address of updater to remove.
    */
    function removeCoverLimitUpdater(address updater) external override onlyGovernance {
        require(updater != address(0x0), "zero address coverlimit updater");
        delete canUpdateCoverLimit[updater];
        emit CoverLimitUpdaterDeleted(updater);
    }

    /***************************************
    RISK MANAGER VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Checks if the given risk strategy is active.
     * @param strategy_ The risk strategy.
     * @return status True if the strategy is active.
     */
    function strategyIsActive(address strategy_) public view override returns (bool status) {
        return _strategies[strategy_].status == StrategyStatus.ACTIVE;
    }

    /**
    * @notice Return the strategy at an index.
    * @dev Enumerable `[1, numStrategies]`.
    * @param index_ Index to query.
    * @return strategy The product address.
    */
    function strategyAt(uint256 index_) external view override returns (address strategy) {
       return _indexToStrategy[index_];
    }

    /**
     * @notice Returns the number of registered strategies..
     * @return count The number of strategies.
    */
    function numStrategies() external view override returns (uint256 count) {
        return _strategyCount;
    }

    /**
     * @notice Returns the risk strategy information.
     * @param strategy_ The risk strategy.
     * @return id The id of the risk strategy.
     * @return weight The risk strategy weight allocation.
     * @return status The status of risk strategy.
     * @return timestamp The added time of the risk strategy.
     *
    */
    function strategyInfo(address strategy_) external view override returns (uint256 id, uint32 weight, StrategyStatus status, uint256 timestamp) {
        Strategy memory strategy = _strategies[strategy_];
        return (strategy.id, strategy.weight, strategy.status, strategy.timestamp);
    }

    /**
     * @notice Returns the allocated weight for the risk strategy.
     * @param strategy_ The risk strategy.
     * @return weight The risk strategy weight allocation.
    */
    function weightPerStrategy(address strategy_) public view override returns (uint32 weight) {
        Strategy memory strategy = _strategies[strategy_];
        return strategy.weight;
    }

    /**
     * @notice The maximum amount of cover that Solace as a whole can sell.
     * @return cover The max amount of cover in wei.
     */
    function maxCover() public view override returns (uint256 cover) {
        return ICoverageDataProvider(_registry.get("coverageDataProvider")).maxCover() * MAX_BPS / _partialReservesFactor;
    }

    /**
     * @notice The maximum amount of cover for given strategy can sell.
     * @return cover The max amount of cover in wei.
     */
     function maxCoverPerStrategy(address strategy_) public view override returns (uint256 cover) {
        if (!strategyIsActive(strategy_)) return 0;
        uint256 maxCoverage = maxCover();
        uint32 weight = weightPerStrategy(strategy_);
        return maxCoverage = (maxCoverage * weight) / weightSum();
    }

    /**
     * @notice Returns the sum of allocation weights for all strategies.
     * @return sum WeightSum.
     */
    function weightSum() public view override returns (uint32 sum) {
        return _weightSum == 0 ? type(uint32).max : _weightSum;
    }

    /**
     * @notice Returns the current amount covered (in wei).
     * @return amount The covered amount (in wei).
    */
    function activeCoverLimit() public view override returns (uint256 amount) {
        return _activeCoverLimit;
    }

    /**
     * @notice Returns the current amount covered (in wei).
     * @param riskStrategy The risk strategy address.
     * @return amount The covered amount (in wei).
    */
    function activeCoverLimitPerStrategy(address riskStrategy) public view override returns (uint256 amount) {
        return _activeCoverLimitPerStrategy[riskStrategy];
    }

    /***************************************
    MIN CAPITAL VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice The minimum amount of capital required to safely cover all policies.
     * @return mcr The minimum capital requirement.
     */
    function minCapitalRequirement() external view override returns (uint256 mcr) {
        return activeCoverLimit() * _partialReservesFactor / MAX_BPS;
    }

    /**
     * @notice The minimum amount of capital required to safely cover all policies.
     * @dev The strategy could have active policies when it is disabled. Because of that
     * we are not adding "strategyIsActive()" require statement.
     * @param strategy The risk strategy.
     * @return smcr The strategy minimum capital requirement.
     */
    function minCapitalRequirementPerStrategy(address strategy) public view override returns (uint256 smcr) {
        return activeCoverLimitPerStrategy(strategy) * _partialReservesFactor / MAX_BPS;
    }

    /**
     * @notice Multiplier for minimum capital requirement.
     * @return factor Partial reserves factor in BPS.
     */
    function partialReservesFactor() external view override returns (uint16 factor) {
        return _partialReservesFactor;
    }

    /**
     * @notice Sets the partial reserves factor.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param partialReservesFactor_ New partial reserves factor in BPS.
     */
    function setPartialReservesFactor(uint16 partialReservesFactor_) external override onlyGovernance {
        _partialReservesFactor = partialReservesFactor_;
        emit PartialReservesFactorSet(partialReservesFactor_);
    }

    /**
     * @notice The function checks if the new weight allocation is valid.
     * @param strategy_ The strategy address.
     * @param weight_ The weight allocation to set.
     * @return status True if the weight allocation is valid.
    */
    function validateAllocation(address strategy_, uint32 weight_) private view returns(bool status) {
        Strategy memory riskStrategy = _strategies[strategy_];
        uint32 weightsum = _weightSum;
        // check if new allocation is valid for the strategy
        uint256 smcr = minCapitalRequirementPerStrategy(strategy_);
        uint256 mc = maxCover();
        weightsum = weightsum + weight_ - riskStrategy.weight;
        uint256 newAllocationAmount = (mc * weight_) / weightsum;

        if (newAllocationAmount < smcr) return false;

        // check other risk strategies
        uint256 strategyCount = _strategyCount;
        for (uint256 i = strategyCount; i > 0; i--) {
            address strategy = _indexToStrategy[i];
            riskStrategy = _strategies[strategy];
            smcr = minCapitalRequirementPerStrategy(strategy);

            if (strategy == strategy_ || riskStrategy.weight == 0 || smcr == 0) continue;
            newAllocationAmount = (mc * riskStrategy.weight) / weightsum;
            if (newAllocationAmount < smcr) return false;
        }
        return true;
    }
}