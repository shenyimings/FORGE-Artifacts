// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

// extends
import "../interfaces/spool/ISpoolExternal.sol";
import "./SpoolReallocation.sol";

/**
 * @notice Exposes spool functions to set and redeem actions.
 *
 * @dev
 * Most of the functions are restricted to vaults. The action is
 * recorded in the buffer system and is processed at the next
 * do hard work.
 * A user cannot interact with any of the Spool functions directly.
 *
 * Complete interaction with Spool consists of 4 steps
 * 1. deposit
 * 2. redeem shares
 * 3. withdraw
 * 4. redeem underlying asset
 *
 * Redeems (step 2. and 4.) are done at the same time. Redeem is
 * processed automatically on first vault interaction after the DHW
 * is completed.
 *
 * As the system works asynchronously, between every step
 * a do hard work needs to be executed. The shares and actual
 * withdrawn amount are only calculated at the time of action (DHW). 
 */
abstract contract SpoolExternal is ISpoolExternal, SpoolReallocation {
    using Bitwise for uint256;
    using SafeERC20 for IERC20;
    using Max128Bit for uint128;

    /* ========== DEPOSIT ========== */

    /**
     * @notice Allows a vault to queue a deposit to a single-collateral strategy.
     *
     * @dev
     * Requirements:
     *
     * - the caller must be a vault
     * - strategy shouldn't be removed
     */
    function deposit(address strat, uint128 amount, uint256 index)
        external
        override
        onlyVault
        notRemoved(strat)
    {
        Strategy storage strategy = strategies[strat];
        Pending storage strategyPending = _getStrategyPending(strategy, index);

        Vault storage vault = strategy.vaults[msg.sender];
        VaultBatch storage vaultBatch = vault.vaultBatches[index];

        // save to storage
        strategyPending.deposit = strategyPending.deposit.add(amount);
        vaultBatch.deposited += amount;

        emit SpoolDeposit(msg.sender, strat);
    }

    /* ========== WITHDRAW ========== */

    /**
     * @notice Allows a vault to queue a withdrawal from a strategy.
     *
     * @dev
     * Requirements:
     *
     * - the caller must be a vault
     * - strategy shouldn't be removed
     */
    function withdraw(address strat, uint256 vaultProportion, uint256 index)
        external
        override
        onlyVault
        notRemoved(strat)
    {
        Strategy storage strategy = strategies[strat];
        Pending storage strategyPending = _getStrategyPending(strategy, index);

        Vault storage vault = strategy.vaults[msg.sender];
        VaultBatch storage vaultBatch = vault.vaultBatches[index];

        // calculate new shares to withdraw
        uint128 sharesToWithdraw = Math.getProportion128(vault.shares, vaultProportion, ACCURACY);

        // save to storage
        strategyPending.sharesToWithdraw = strategyPending.sharesToWithdraw.add(sharesToWithdraw);
        vaultBatch.withdrawnShares += sharesToWithdraw;

        emit SpoolWithdraw(msg.sender, strat);
    }

    /* ========== DEPOSIT/WITHDRAW SHARED ========== */

    /**
     * @notice Get strategy pending struct, depending on if the strategy do hard work has already been executed in the current index
     */
    function _getStrategyPending(Strategy storage strategy, uint256 interactingIndex) private view returns (Pending storage pending) {
        // if index we are interacting with (active global index) is same as strategy index, then DHW has already been executed in index
        if (_isNextStrategyIndex(strategy, interactingIndex)) {
            pending = strategy.pendingUser;
        } else {
            pending = strategy.pendingUserNext;
        }
    }

    /* ========== REDEEM ========== */

    /**
     * @notice Allows a vault to redeem deposit and withdrawals for the processed index.
     *
     * Requirements:
     *
     * - the caller must be a valid vault
     */
    function redeem(address strat, uint256 index)
        external
        override
        onlyVault
        returns (uint128, uint128)
    {
        Strategy storage strategy = strategies[strat];
        Batch storage batch = strategy.batches[index];
        Vault storage vault = strategy.vaults[msg.sender];
        VaultBatch storage vaultBatch = vault.vaultBatches[index];

        uint128 vaultBatchDeposited = vaultBatch.deposited;
        uint128 vaultBatchWithdrawnShares = vaultBatch.withdrawnShares;

        uint128 vaultDepositReceived = 0;
        uint128 vaultWithdrawnReceived = 0;
        uint128 vaultShares = vault.shares;

        // Make action if deposit in vault batch was performed
        if (vaultBatchDeposited > 0 && batch.deposited > 0) {
            vaultDepositReceived = (batch.depositedRecieved * vaultBatchDeposited) / batch.deposited;
            vaultShares += (batch.depositedSharesRecieved * vaultBatchDeposited) / batch.deposited;

            vaultBatch.deposited = 0;
        }

        // Make action if withdraw in vault batch was performed
        if (vaultBatchWithdrawnShares > 0 && batch.withdrawnShares > 0) {
            vaultWithdrawnReceived = (batch.withdrawnRecieved * vaultBatchWithdrawnShares) / batch.withdrawnShares;

            vaultShares -= vaultBatchWithdrawnShares;

            vaultBatch.withdrawnShares = 0;
        }

        vault.shares = vaultShares;

        emit SpoolRedeem(msg.sender, strat);

        return (vaultDepositReceived, vaultWithdrawnReceived);
    }

    function redeemUnderlying(uint128 amount) external override onlyVault {
        IVault(msg.sender).underlying().safeTransfer(msg.sender, amount);
    }

    /* ========== REDEEM REALLOCATION ========== */

    /**
     * @notice Redeem vault shares after vault reallocation has been performed
     */
    function redeemReallocation(
        address[] memory vaultStrategies,
        uint256 depositProportions,
        uint256 index
    ) external override onlyVault {
        // count strategies we deposit into
        uint128 depositStratsCount = 0;
        for (uint256 i = 0; i < vaultStrategies.length; i++) {
            uint256 prop = depositProportions.get14BitUintByIndex(i);
            if (prop > 0) {
                depositStratsCount++;
            }
        }

        // init deposit and withdrawal strategy arrays
        address[] memory withdrawStrats = new address[](vaultStrategies.length - depositStratsCount);
        address[] memory depositStrats = new address[](depositStratsCount);
        uint256[] memory depositProps = new uint256[](depositStratsCount);

        // fill deposit and withdrawal strategy arrays 
        {
            uint128 k = 0;
            uint128 l = 0;
            for (uint256 i = 0; i < vaultStrategies.length; i++) {
                uint256 prop = depositProportions.get14BitUintByIndex(i);
                if (prop > 0) {
                    depositStrats[k] = vaultStrategies[i];
                    depositProps[k] = prop;
                    k++;
                } else {
                    withdrawStrats[l] = vaultStrategies[i];
                    l++;
                }
            }
        }

        uint256 totalVaultWithdrawnReceived = 0;

        // calculate total withdrawal amount 
        for (uint256 i = 0; i < withdrawStrats.length; i++) {
            Strategy storage strategy = strategies[withdrawStrats[i]];
            BatchReallocation storage batch = strategy.reallocationBatches[index];
            Vault storage vault = strategy.vaults[msg.sender];
            
            // if we withdrawed from strategy, claim and spread across deposits
            uint256 vaultWithdrawnReallocationShares = vault.withdrawnReallocationShares;
            if (vaultWithdrawnReallocationShares > 0 && batch.withdrawnReallocationShares > 0) {
                totalVaultWithdrawnReceived += (batch.withdrawnReallocationRecieved * vaultWithdrawnReallocationShares) / batch.withdrawnReallocationShares;

                vault.shares -= SafeCast.toUint128(vaultWithdrawnReallocationShares);
                vault.withdrawnReallocationShares = 0;
            }
        }

        uint256 vaultWithdrawnReceivedLeft = totalVaultWithdrawnReceived;
        uint256 lastDepositStratIndex = depositStratsCount - 1;
        for (uint256 i = 0; i < depositStratsCount; i++) {
            Strategy storage depositStrategy = strategies[depositStrats[i]];
            Vault storage depositVault = depositStrategy.vaults[msg.sender];
            BatchReallocation storage batch = depositStrategy.reallocationBatches[index];
            if (batch.depositedReallocation > 0) {
                // calculate reallication strat deposit amount
                uint256 depositAmount;
                if (i < lastDepositStratIndex) {
                    depositAmount = (totalVaultWithdrawnReceived * depositProps[i]) / FULL_PERCENT;
                    vaultWithdrawnReceivedLeft -= depositAmount;
                } else { // if strat is last use deposit left
                    depositAmount = vaultWithdrawnReceivedLeft;
                }

                depositVault.shares += SafeCast.toUint128((batch.depositedReallocationSharesRecieved * depositAmount) / batch.depositedReallocation);
            }
        }

        emit SpoolRedeemReallocation(msg.sender);
    }

    /* ========== FAST WITHDRAW ========== */

    /**
     * @notice Fast withdtaw from a strategy.
     *
     * @dev
     * Performs immediate withdrawal executing strategy protocol
     * functions directly.
     * Can be very gas expensive, especially if executing it for
     * multiple strategies.
     *
     * Requirements:
     *
     * - the caller must be a fast withdraw contract
     * - strategy shouldn't be removed
     */
    function fastWithdrawStrat(
        address strat,
        address underlying,
        uint256 shares,
        uint256[] memory slippages,
        SwapData[] memory swapData
    )
        external
        override
        onlyFastWithdraw
        notRemoved(strat)
        returns(uint128)
    {
        // returns withdrawn amount
        return  _fastWithdrawStrat(strat, underlying, shares, slippages, swapData);
    }

    /* ========== REMOVE SHARES (prepare for fast withdraw) ========== */

    /**
     * @notice Remove vault shares.
     *
     * @dev
     * Requirements:
     *
     * - can only be called by the vault
     */
    function removeShares(
        address[] memory vaultStrategies,
        uint256 vaultProportion
    )
        external
        override
        onlyVault
        returns(uint128[] memory)
    {
        uint128[] memory removedShares = new uint128[](vaultStrategies.length);

        for (uint128 i = 0; i < vaultStrategies.length; i++) {
            _notRemoved(vaultStrategies[i]);
            Strategy storage strategy = strategies[vaultStrategies[i]];

            Vault storage vault = strategy.vaults[msg.sender];

            uint128 sharesToWithdraw = Math.getProportion128(vault.shares, vaultProportion, ACCURACY);

            removedShares[i] = sharesToWithdraw;
            vault.shares -= sharesToWithdraw;
        }

        emit SpoolSharesRemoved(msg.sender);
        
        return removedShares;
    }

    // REMOVE SHARES WHILE REALLOCATING

    /**
     * @notice Remove vault shares while vault reallocation is pending.
     *
     * @dev
     * Requirements:
     *
     * - can only be called by the vault
     */
    function removeSharesDuringVaultReallocation(
        VaultWithdraw memory vaultWithdraw,
        FastWithdrawalReallocation memory reallocation,
        uint256[][] memory reallocationProportions
    )
        external
        override
        onlyVault
        verifyStrategies(reallocation.allStrategies)
        verifyVaultStrategies(vaultWithdraw.strategies, reallocation.vaultStrategiesBitwise, reallocation.allStrategies)
        returns(uint128[] memory)
    {
        _verifyReallocationProportions(reallocationProportions);

        uint128[] memory removedShares = new uint128[](vaultWithdraw.strategies.length);

        for (uint128 i = 0; i < vaultWithdraw.strategies.length; i++) {
            _notRemoved(vaultWithdraw.strategies[i]);
            Strategy storage strategy = strategies[vaultWithdraw.strategies[i]];

            Vault storage vault = strategy.vaults[msg.sender];

            uint128 sharesToWithdraw = Math.getProportion128((vault.shares - vault.withdrawnReallocationShares), vaultWithdraw.withdrawnProportion, ACCURACY);

            sharesToWithdraw += _getWithdrawnShares(
                i,
                vaultWithdraw,
                reallocation,
                reallocationProportions
            );

            removedShares[i] = sharesToWithdraw;
            vault.shares -= sharesToWithdraw;
        }

        _hashReallocationProportions(reallocationProportions);

        emit SpoolSharesRemovedReallocating(msg.sender);
        
        return removedShares;
    }

    function _getWithdrawnShares(
        uint128 i,
        VaultWithdraw memory vaultWithdraw,
        FastWithdrawalReallocation memory reallocation,
        uint256[][] memory reallocationProportions
    ) private returns (uint128 removedShares){
        Strategy storage strategy = strategies[vaultWithdraw.strategies[i]];
        Vault storage vault = strategy.vaults[msg.sender];
        if (vault.withdrawnReallocationShares > 0) {
            uint256 globalStratIndex = reallocation.vaultStrategiesBitwise.get8BitUintByIndex(i);
            removedShares = _updateRemovedReallocationForStrat(
                vault.withdrawnReallocationShares,
                vaultWithdraw,
                reallocation,
                reallocationProportions[globalStratIndex]
            );

            vault.withdrawnReallocationShares -= removedShares;
        }
    }

    function _updateRemovedReallocationForStrat(
        uint128 initialSharesWithdrawn,
        VaultWithdraw memory vaultWithdraw,
        FastWithdrawalReallocation memory reallocation,
        uint256[] memory stratReallocationProportions
    ) private pure returns (uint128 removedShares) {
        uint128 sharesWithdrawnleft = initialSharesWithdrawn;
        uint128 lastDepositedIndex = 0;
        for (uint128 i = 0; i < vaultWithdraw.strategies.length; i++) {

            uint256 stratDepositProportion = reallocation.depositProportions.get14BitUintByIndex(i);
            if (stratDepositProportion > 0) {
                uint256 globalStratIndex = reallocation.vaultStrategiesBitwise.get8BitUintByIndex(i);

                uint128 withdrawnSharesForStrat = Math.getProportion128(initialSharesWithdrawn, stratDepositProportion, FULL_PERCENT);

                uint128 removedWithdrawnSharesForStrat = Math.getProportion128(withdrawnSharesForStrat, vaultWithdraw.withdrawnProportion, ACCURACY);
                removedShares += removedWithdrawnSharesForStrat;

                stratReallocationProportions[globalStratIndex] -= removedWithdrawnSharesForStrat;
                sharesWithdrawnleft -= withdrawnSharesForStrat;
                lastDepositedIndex = i;
            }
        }

        // add shares left from rounding error to last deposit strat
        {
            uint128 removedWithdrawnSharesForStratLeft = Math.getProportion128(sharesWithdrawnleft, vaultWithdraw.withdrawnProportion, ACCURACY);
            removedShares += removedWithdrawnSharesForStratLeft;
            stratReallocationProportions[lastDepositedIndex] -= removedWithdrawnSharesForStratLeft;
        }
    }
}