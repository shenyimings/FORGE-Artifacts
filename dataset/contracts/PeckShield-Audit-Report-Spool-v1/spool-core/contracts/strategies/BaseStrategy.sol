// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../interfaces/IBaseStrategy.sol";
import "../shared/BaseStorage.sol";
import "../shared/Constants.sol";

import "../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../libraries/Math.sol";
import "../libraries/Max/128Bit.sol";

/**
 * @notice Implementation of the {IBaseStrategy} interface.
 *
 * @dev
 * This implementation of the {IBaseStrategy} is meant to operate
 * on single-collateral strategies and uses a delta system to calculate
 * whether a withdrawal or deposit needs to be performed for a particular
 * strategy.
 */
abstract contract BaseStrategy is IBaseStrategy, BaseStorage, BaseConstants {
    using SafeERC20 for IERC20;
    using Max128Bit for uint128;

    /* ========== STATE VARIABLES ========== */

    /// @notice The total slippage slots the strategy supports, used for validation of provided slippage
    uint256 internal immutable rewardSlippageSlots;
    uint256 internal immutable processSlippageSlots;
    uint256 internal immutable reallocationSlippageSlots;
    uint256 internal immutable depositSlippageSlots;

    /** 
     * @notice do force claim of rewards.
     *
     * @dev
     * Some strategies auto claim on deposit/withdraw,
     * so execute the claim actions to store the reward amounts.
     */
    bool internal immutable forceClaim;

    /// @notice The self address, set at initialization to allow proper share accounting
    address internal immutable self;

    /// @notice The underlying asset of the strategy
    IERC20 public immutable override underlying;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Initializes the base strategy values.
     *
     * @dev
     * It performs certain pre-conditional validations to ensure the contract
     * has been initialized properly, such as that the address argument of the
     * underlying asset is valid.
     *
     * Slippage slots for certain strategies may be zero if there is no compounding
     * work to be done.
     * 
     * @param _underlying token used for deposits
     * @param _rewardSlippageSlots slots for rewards
     * @param _processSlippageSlots slots for processing
     * @param _reallocationSlippageSlots slots for reallocation
     * @param _depositSlippageSlots slots for deposits
     * @param _forceClaim force claim of rewards
     */
    constructor(
        IERC20  _underlying,
        uint256 _rewardSlippageSlots,
        uint256 _processSlippageSlots,
        uint256 _reallocationSlippageSlots,
        uint256 _depositSlippageSlots,
        bool _forceClaim
    ) {
        require(
            _underlying != IERC20(address(0)),
            "BaseStrategy::constructor: Underlying address cannot be 0"
        );

        self = address(this);
        underlying = _underlying;
        rewardSlippageSlots = _rewardSlippageSlots;
        processSlippageSlots = _processSlippageSlots;
        reallocationSlippageSlots = _reallocationSlippageSlots;
        depositSlippageSlots = _depositSlippageSlots;
        forceClaim = _forceClaim;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Process the latest pending action of the strategy
     *
     * @dev
     * it yields amount of funds processed as well as the reward buffer of the strategy.
     * The function will auto-compound rewards if requested and supported.
     *
     * Requirements:
     *
     * - the slippages provided must be valid in length
     * - if the redeposit flag is set to true, the strategy must support
     *   compounding of rewards
     *
     * @param slippages slippages to process
     * @param redeposit if redepositing is to occur
     * @param swapData swap data for processing
     */
    function process(uint256[] calldata slippages, bool redeposit, SwapData[] calldata swapData) external override
    {
        if (forceClaim || redeposit) {
            _validateRewardsSlippage(swapData);
            _processRewards(swapData);
        }

        if (processSlippageSlots != 0)
            _validateProcessSlippage(slippages);
        
        _process(slippages, 0);
    }

    function processReallocation(uint256[] calldata slippages, ProcessReallocationData calldata processReallocationData) external override returns(uint128)
    {
        if (reallocationSlippageSlots != 0)
            _validateReallocationSlippage(slippages);

        _process(slippages, processReallocationData.sharesToWithdraw);

        uint128 withdrawnReallocationRecieved = _updateReallocationWithdraw(processReallocationData);

        return withdrawnReallocationRecieved;
    }

    function _updateReallocationWithdraw(ProcessReallocationData calldata processReallocationData) internal virtual returns(uint128) {
        Strategy storage strategy = strategies[self];
        uint24 stratIndex = _getProcessingIndex();
        BatchReallocation storage batch = strategy.reallocationBatches[stratIndex];

        // save actual withdrawn amount, without optimized one 
        uint128 withdrawnReallocationRecieved = batch.withdrawnReallocationRecieved;

        strategy.optimizedSharesWithdrawn += processReallocationData.optimizedShares;
        batch.withdrawnReallocationRecieved += processReallocationData.optimizedWithdrawnAmount;
        batch.withdrawnReallocationShares = processReallocationData.optimizedShares + processReallocationData.sharesToWithdraw;

        return withdrawnReallocationRecieved;
    }

    function processDeposit(uint256[] calldata slippages)
        external
        override
    {
        if (depositSlippageSlots != 0)
            _validateDepositSlippage(slippages);

        _processDeposit(slippages);
    }

    function getStrategyUnderlyingWithRewards() public view override returns(uint128)
    {
        return _getStrategyUnderlyingWithRewards();
    }

    function fastWithdraw(uint128 shares, uint256[] calldata slippages, SwapData[] calldata swapData) external override returns(uint128)
    {
        _validateRewardsSlippage(swapData);

        if (processSlippageSlots != 0)
            _validateProcessSlippage(slippages);

        uint128 withdrawnAmount = _processFastWithdraw(shares, slippages, swapData);
        strategies[self].totalShares -= shares;
        return withdrawnAmount;
    }

    /**
     * @notice Claims and possibly compounds strategy rewards.
     *
     * @param swapData swap data for processing
     */
    function claimRewards(SwapData[] calldata swapData) external override
    {
        _validateRewardsSlippage(swapData);
        _processRewards(swapData);
    }

    /**
     * @notice Withdraws all actively deployed funds in the strategy, liquifying them in the process.
     *
     * @param recipient recipient of the withdrawn funds
     * @param data data necessary execute the emergency withdraw
     */
    function emergencyWithdraw(address recipient, uint256[] calldata data) external virtual override {
        uint256 balanceBefore = underlying.balanceOf(address(this));
        _emergencyWithdraw(recipient, data);
        uint256 balanceAfter = underlying.balanceOf(address(this));

        uint256 withdrawnAmount = 0;
        if (balanceAfter > balanceBefore) {
            withdrawnAmount = balanceAfter - balanceBefore;
        }
        
        Strategy storage strategy = strategies[self];

        // also withdraw all unprocessed deposit for a strategy
        if (strategy.pendingUser.deposit.get() > 0) {
            withdrawnAmount += strategy.pendingUser.deposit.get();
            strategy.pendingUser.deposit = 0;
        }

        if (strategy.pendingUserNext.deposit.get() > 0) {
            withdrawnAmount += strategy.pendingUserNext.deposit.get();
            strategy.pendingUserNext.deposit = 0;
        }

        // if strategy was already processed in the current index that hasn't finished yet,
        // transfer the withdrawn amount
        // reset total underlying to 0
        if (strategy.index == globalIndex && doHardWorksLeft > 0) {
            uint256 withdrawnRecieved = strategy.batches[strategy.index].withdrawnRecieved;
            withdrawnAmount += withdrawnRecieved;
            strategy.batches[strategy.index].withdrawnRecieved = 0;

            strategy.totalUnderlying[strategy.index].amount = 0;
        }

        if (withdrawnAmount > 0) {
            // check if the balance is high enough to withdraw the total withdrawnAmount
            if (balanceAfter < withdrawnAmount) {
                // if not withdraw the current balance
                withdrawnAmount = balanceAfter;
            }

            underlying.safeTransfer(recipient, withdrawnAmount);
        }
    }

    /**
     * @notice Initialize a strategy.
     * @dev Execute strategy specific one-time actions if needed.
     */
    function initialize() external virtual override {}

    /**
     * @notice Disables a strategy.
     * @dev Cleans strategy specific values if needed.
     */
    function disable() external virtual override {}

    /* ========== INTERNAL FUNCTIONS ========== */

    function _validateRewardsSlippage(SwapData[] calldata swapData) internal view virtual {
        if (swapData.length > 0) {
            require(
                swapData.length == _getRewardSlippageSlots(),
                "BaseStrategy::_validateSlippage: Invalid Number of reward slippages Defined"
            );
        }
    }

    function _getRewardSlippageSlots() internal view virtual returns(uint256) {
        return rewardSlippageSlots;
    }

    function _validateProcessSlippage(uint256[] calldata slippages) internal view virtual {
        _validateSlippage(slippages.length, processSlippageSlots);
    }

    function _validateReallocationSlippage(uint256[] calldata slippages) internal view virtual {
        _validateSlippage(slippages.length, reallocationSlippageSlots);
    }

    function _validateDepositSlippage(uint256[] calldata slippages) internal view virtual {
        _validateSlippage(slippages.length, depositSlippageSlots);
    }

    /**
     * @notice Validates the provided slippage in length.
     */
    function _validateSlippage(uint256 currentLength, uint256 shouldBeLength)
        internal
        view
        virtual
    {
        require(
            currentLength == shouldBeLength,
            "BaseStrategy::_validateSlippage: Invalid Number of Slippages Defined"
        );
    }

    function _getProcessingIndex() internal view returns(uint24) {
        return strategies[self].index + 1;
    }

    /**
     * @notice Calculates shares before they are added to the total shares
     */
    function _getNewSharesAfterWithdraw(uint128 strategyTotalShares, uint128 stratTotalUnderlying, uint128 depositAmount) internal pure returns(uint128 newShares){
        uint128 oldUnderlying;
        if (stratTotalUnderlying > depositAmount) {
            oldUnderlying = stratTotalUnderlying - depositAmount;
        }
        
        if (strategyTotalShares == 0 || oldUnderlying == 0) {
            newShares = depositAmount;
        } else {
            newShares = Math.getProportion128(depositAmount, strategyTotalShares, oldUnderlying);
        }
    }

    /**
     * @notice Calculates shares when they are already part of the total shares
     */
    function _getNewShares(uint128 strategyTotalShares, uint128 stratTotalUnderlying, uint128 depositAmount) internal pure returns(uint128 newShares){
        if (strategyTotalShares == 0 || stratTotalUnderlying == 0) {
            newShares = depositAmount;
        } else {
            newShares = Math.getProportion128(depositAmount, strategyTotalShares, stratTotalUnderlying);
        }
    }

    /* ========== VIRTUAL FUNCTIONS ========== */

    function getStrategyBalance()
        public
        view
        virtual
        override
        returns (uint128);

    function _processRewards(SwapData[] calldata) internal virtual;
    function _emergencyWithdraw(address recipient, uint256[] calldata data) internal virtual;
    function _process(uint256[] memory, uint128 redistributeSharesToWithdraw) internal virtual;
    function _processDeposit(uint256[] memory) internal virtual;
    function _getStrategyUnderlyingWithRewards() internal view virtual returns(uint128);
    function _processFastWithdraw(uint128, uint256[] memory, SwapData[] calldata) internal virtual returns(uint128);
}
