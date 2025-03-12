// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

// extends
import "../interfaces/spool/ISpoolStrategy.sol";
import "./SpoolBase.sol";

// libraries
import "../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../libraries/Max/128Bit.sol";
import "../libraries/Hash.sol";

// other imports
import "../interfaces/IBaseStrategy.sol";

/**
 * @notice Spool part of implementation dealing with strategy related processing
 */
abstract contract SpoolStrategy is ISpoolStrategy, SpoolBase {
    using SafeERC20 for IERC20;

    /* ========== VIEWS ========== */

    /**
     * @notice Returns the amount of funds the vault caller has in total
     * deployed to a particular strategy.
     *
     * @dev
     * Although not set as a view function due to the delegatecall
     * instructions performed by it, its value can be acquired
     * without actually executing the function by both off-chain
     * and on-chain code via simulating the transaction's execution.
     *
     * @param strat strategy address
     *
     * @return amount
     */
    function getUnderlying(address strat) external override returns (uint128) {
        Strategy storage strategy = strategies[strat];

        uint128 totalStrategyShares = strategy.totalShares;
        if (totalStrategyShares == 0) return 0;

        return (_totalUnderlying(strat) * strategy.vaults[msg.sender].shares) / totalStrategyShares;
    }

    /**
     * @notice Returns total strategy underlying value.
     */
    function getStratUnderlying(address strat) external returns (uint128) {
        return _totalUnderlying(strat); // deletagecall
    }

    /**
     * @notice Get total vault underlying at index.
     *
     * @dev
     * NOTE: Call ONLY if vault shares are correct for the index.
     *       Meaning vault has just redeemed for this index or this is current index.
     *
     * @param strat strategy address
     * @param index index in total underlying
     */
    function getVaultTotalUnderlyingAtIndex(address strat, uint256 index) external override view returns(uint128) {
        Strategy storage strategy = strategies[strat];
        Vault storage vault = strategy.vaults[msg.sender];
        TotalUnderlying memory totalUnderlying = strategy.totalUnderlying[index];

        if (totalUnderlying.totalShares > 0) {
            return (totalUnderlying.amount * vault.shares) / totalUnderlying.totalShares;
        }
        
        return 0;
    }

    /**
     * @notice Returns current valid strategy count.
     */
    function _getStrategiesCount() internal view returns(uint8) {
        return controller.getStrategiesCount();
    }
    
    /**
     * @notice Yields the total underlying funds of a strategy.
     *
     * @dev
     * The function is not set as view given that it performs a delegate call
     * instruction to the strategy.
     */
    function _totalUnderlying(address strategy)
        internal
        returns (uint128)
    {
        bytes memory data = _relay(
            strategy,
            abi.encodeWithSelector(IBaseStrategy.getStrategyBalance.selector)
        );

        return abi.decode(data, (uint128));
    }

    function _getStratValue(
        address strategy
    ) internal returns(uint128) {
        bytes memory data = _relay(
            strategy,
            abi.encodeWithSelector(
                IBaseStrategy.getStrategyUnderlyingWithRewards.selector
            )
        );

        return abi.decode(data, (uint128));
    }

    /* ========== MUTATIVE EXTERNAL FUNCTIONS ========== */

    /**
     * @notice Adds and initializes a new strategy
     *
     * @dev
     * Requirements:
     *
     * - the caller must be the controller
     * - reallcation must not be pending
     * - strategy shouldn't be previously removed
     */
    function addStrategy(address strat)
        external
        override
        onlyController
        noPendingReallocation
        notRemoved(strat)
    {
        Strategy storage strategy = strategies[strat];

        strategy.index = globalIndex;
        // init as max zero, so first user interaction will be cheaper (non-zero to non-zero storage change)
        strategy.pendingUser = Pending(Max128Bit.ZERO, Max128Bit.ZERO);
        strategy.pendingUserNext = Pending(Max128Bit.ZERO, Max128Bit.ZERO);

        // initialize strategy specific values
        _initializeStrategy(strat);
    }

    /**
     * @notice Disables a strategy by liquidating all actively deployed funds
     * within it to its underlying collateral.
     *
     * @dev
     * This function is invoked whenever a strategy is disabled at the controller
     * level as an emergency.
     *
     * Requirements:
     *
     * - the caller must be the controller
     * - the reallocation shouldn't be pending
     * - strategy shouldn't be previously removed
     *
     * @param strat strategy being disabled
     * @param skipDisable flag to skip executing strategy specific disable function
     *  NOTE: Should always be false, except if `IBaseStrategy.disable` is failing and there is no other way
     */
    function disableStrategy(
        address strat,
        bool skipDisable
    )
        external
        override
        onlyController
        noPendingReallocation
        notRemoved(strat)
    {

        // TODO: Add mid reallocation logic
        Strategy storage strategy = strategies[strat];

        // check if the strategy has already been processed in ongoing do hard work
        if (strategy.index != globalIndex) {
            doHardWorksLeft--;
        } else if (!_isBatchComplete()) {
            strategy.emergencyPending += strategy.batches[strategy.index].withdrawnRecieved;
            strategy.batches[strategy.index].withdrawnRecieved = 0;

            strategy.totalUnderlying[strategy.index].amount = 0;
        }

        strategy.isRemoved = true;

        if (!skipDisable) {
            _disableStrategy(strat);
        } else {
            _skippedDisable[strat] = true;
        }

        _awaitingEmergencyWithdraw[strat] = true;
    }

    /**
     * @notice Liquidating all actively deployed funds within a strategy after it was disabled.
     *
     * @dev
     * Requirements:
     *
     * - the caller must be the controller
     * - the strategy must be disabled
     * - the strategy must be awaiting emergency withdraw
     *
     * @param strat strategy being disabled
     * @param data data to perform the withdrawal
     * @param withdrawRecipient recipient of the withdrawn funds
     */
    function emergencyWithdraw(
        address strat,
        address withdrawRecipient,
        uint256[] memory data
    )
        external
        override
        onlyController
        onlyRemoved(strat)
    {
        require(_awaitingEmergencyWithdraw[strat], "SEWP");

        _emergencyWithdraw(strat, withdrawRecipient, data);

        _awaitingEmergencyWithdraw[strat] = false;
    }

    /**
     * @notice Runs strategy specific disable function if it was skipped when disabling the strategy.
     */
    function runDisableStrategy(address strat)
        external
        override
        onlyController
        onlyRemoved(strat)
    {
        require(_skippedDisable[strat], "SDEX");

        _disableStrategy(strat);
        _skippedDisable[strat] = false;
    }

    /* ========== MUTATIVE INTERNAL FUNCTIONS ========== */

    /**
     * @notice Invokes the process function on the strategy to either deposit to or withdraw from it
     */
    function _process(
        address strategy,
        uint256[] memory slippages,
        bool harvestRewards,
        SwapData[] memory swapData
    ) internal {
        _relay(
            strategy,
            abi.encodeWithSelector(
                IBaseStrategy.process.selector,
                slippages,
                harvestRewards,
                swapData
            )
        );
    }

    function _processReallocation(
        address strategy,
        uint256[] memory slippages,
        ProcessReallocationData memory processReallocationData
    ) internal returns(uint128) {
        bytes memory data = _relay(
            strategy,
            abi.encodeWithSelector(
                IBaseStrategy.processReallocation.selector,
                slippages,
                processReallocationData
            )
        );

        // return actual withdrawn reallocation underlying assets recieved
        return abi.decode(data, (uint128));
    }

    function _processDeposit(
        address strategy,
        uint256[] memory slippages
    ) internal {
        _relay(
            strategy,
            abi.encodeWithSelector(
                IBaseStrategy.processDeposit.selector,
                slippages
            )
        );
    }

    function _fastWithdrawStrat(
        address strategy,
        address underlying,
        uint256 shares,
        uint256[] memory slippages,
        SwapData[] memory swapData
    ) internal returns(uint128) {
        bytes memory data = _relay(
            strategy,
            abi.encodeWithSelector(
                IBaseStrategy.fastWithdraw.selector,
                shares,
                slippages,
                swapData
            )
        );

        (uint128 withdrawnAmount) = abi.decode(data, (uint128));

        IERC20(underlying).safeTransfer(msg.sender, withdrawnAmount);

        return withdrawnAmount;
    }

    function _claimRewards(
        address strategy,
        SwapData[] memory swapData
    ) internal {
        _relay(
            strategy,
            abi.encodeWithSelector(
                IBaseStrategy.claimRewards.selector,
                swapData
            )
        );
    }

    /**
     * @notice Invokes the emergencyWithdraw function on a strategy
     */
    function _emergencyWithdraw(address strategy, address recipient, uint256[] memory data) internal {
        _relay(
            strategy,
            abi.encodeWithSelector(
                IBaseStrategy.emergencyWithdraw.selector,
                recipient,
                data
            )
        );
    }

    /**
     * @notice Initializes strategy specific values
     */
    function _initializeStrategy(address strategy) internal {
        _relay(
            strategy,
            abi.encodeWithSelector(IBaseStrategy.initialize.selector)
        );
    }

    /**
     * @notice Cleans strategy specific values after disabling
     */
    function _disableStrategy(address strategy) internal {
        _relay(
            strategy,
            abi.encodeWithSelector(IBaseStrategy.disable.selector)
        );
    }

    /**
     * @notice Relays the particular action to the strategy via delegatecall.
     */
    function _relay(address strategy, bytes memory payload)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory data) = strategy.delegatecall(payload);
        if (!success) revert(abi.decode(data, (string)));
        return data;
    }
}