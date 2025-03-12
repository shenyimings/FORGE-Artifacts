// SPDX-License-Identifier: BUSL-1.1

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
     * @notice Allows a vault to queue a deposit to a strategy.
     *
     * @dev
     * Requirements:
     *
     * - the caller must be a vault
     * - strategy shouldn't be removed
     *
     * @param strat Strategy address to deposit to
     * @param amount Amount to deposit
     * @param index Global index vault is depositing at (active global index)
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
     *
     * @param strat Strategy address to withdraw from
     * @param vaultProportion Proportion of all vault-strategy shares a vault wants to withdraw, denoted in basis points (10_000 is 100%)
     * @param index Global index vault is depositing at (active global index)
     */
    function withdraw(address strat, uint256 vaultProportion, uint256 index)
        external
        override
        onlyVault
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
    }

    /* ========== DEPOSIT/WITHDRAW SHARED ========== */

    /**
     * @notice Get strategy pending struct, depending on if the strategy do hard work has already been executed in the current index
     * @param strategy Strategy data (see Strategy struct)
     * @param interactingIndex Global index for which to get the struct
     * @return pending Storage struct containing all unprocessed deposits and withdrawals for the `interactingIndex`
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
     * @dev
     *
     * Requirements:
     *
     * - the caller must be a valid vault
     *
     * @param strat Strategy address
     * @param index Global index the vault is redeeming for
     * @return Received vault received shares from the deposit and received vault underlying withdrawn amounts
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

        // Make calculations if deposit in vault batch was performed
        if (vaultBatchDeposited > 0 && batch.deposited > 0) {
            vaultDepositReceived = Math.getProportion128(batch.depositedReceived, vaultBatchDeposited, batch.deposited);
            // calculate new vault-strategy shares
            // new shares are calculated at the DHW time, here vault only
            // takes the proportion of the vault deposit compared to the total deposit
            vaultShares += Math.getProportion128(batch.depositedSharesReceived, vaultBatchDeposited, batch.deposited);

            // reset to 0 to get the gas reimbursement
            vaultBatch.deposited = 0;
        }

        // Make calculations if withdraw in vault batch was performed
        if (vaultBatchWithdrawnShares > 0 && batch.withdrawnShares > 0) {
            // Withdrawn recieved represents the total underlying a strategy got back after DHW has processed the withdrawn shares.
            // This is stored at the DHW time, here vault only takes the proportion
            // of the vault shares withdrwan compared to the total shares withdrawn
            vaultWithdrawnReceived = Math.getProportion128(batch.withdrawnReceived, vaultBatchWithdrawnShares, batch.withdrawnShares);
            // substract all the shares withdrawn in the index after collecting the withdrawn recieved
            vaultShares -= vaultBatchWithdrawnShares;

            // reset to 0 to get the gas reimbursement
            vaultBatch.withdrawnShares = 0;
        }

        // store the updated shares
        vault.shares = vaultShares;

        return (vaultDepositReceived, vaultWithdrawnReceived);
    }

    /**
     * @notice Redeem underlying token
     * @dev
     * This function is only called by the vault after the vault redeem is processed
     * As redeem is called by each strategy separately, we don't want to transfer the
     * withdrawn underlyin tokens x amount of times. 
     *
     * Requirements:
     * - Can only be invoked by vault
     *
     * @param amount Amount to redeem
     */
    function redeemUnderlying(uint128 amount) external override onlyVault {
        IVault(msg.sender).underlying().safeTransfer(msg.sender, amount);
    }

    /* ========== REDEEM REALLOCATION ========== */

    /**
     * @notice Redeem vault shares after reallocation has been processed for the vault
     * @dev
     *
     * Requirements:
     * - Can only be invoked by vault
     *
     * @param vaultStrategies Array of vault strategy addresses
     * @param depositProportions Values representing how the vault has deposited it's withdrawn shares 
     * @param index Index at which the reallocation was perofmed
     */
    function redeemReallocation(
        address[] memory vaultStrategies,
        uint256 depositProportions,
        uint256 index
    ) external override onlyVault {
        // count number of strategies we deposit into
        uint256 depositStratsCount;
        for (uint256 i; i < vaultStrategies.length; i++) {
            if (depositProportions.get14BitUintByIndex(i) > 0) {
                depositStratsCount++;
            }
        }

        // init deposit and withdrawal strategy arrays
        address[] memory withdrawStrats = new address[](vaultStrategies.length - depositStratsCount);
        address[] memory depositStrats = new address[](depositStratsCount);
        uint256[] memory depositProps = new uint256[](depositStratsCount);

        // fill deposit and withdrawal strategy arrays 
        {
            uint256 k;
            uint256 l;
            for (uint256 i; i < vaultStrategies.length; i++) {
                uint256 prop = depositProportions.get14BitUintByIndex(i);
                if (prop > 0) {
                    depositStrats[k] = vaultStrategies[i];
                    depositProps[k] = prop;
                    unchecked {
                        k++;
                    }
                } else {
                    withdrawStrats[l] = vaultStrategies[i];
                    unchecked {
                        l++;
                    }
                }
            }
        }

        uint256[] memory vaultWithdrawnReceived = new uint256[](withdrawStrats.length);
        uint256[] memory vaultWithdrawnReceivedLeft = new uint256[](withdrawStrats.length);
        // calculate total withdrawal amount 
        for (uint256 i = 0; i < withdrawStrats.length; i++) {
            Strategy storage strategy = strategies[withdrawStrats[i]];
            BatchReallocation storage reallocationBatch = strategy.reallocationBatches[index];
            Vault storage vault = strategy.vaults[msg.sender];
            
            // if we withdrawed from strategy, claim and spread across deposits
            uint256 vaultWithdrawnReallocationShares = vault.withdrawnReallocationShares;
            if (vaultWithdrawnReallocationShares > 0) {
                // if batch withdrawn shares is 0, reallocation was canceled as a strategy was removed
                // if so, skip calculation and reset withdrawn reallcoation shares to 0
                if (reallocationBatch.withdrawnReallocationShares > 0) {
                    vaultWithdrawnReceived[i] = 
                        (reallocationBatch.withdrawnReallocationReceived * vaultWithdrawnReallocationShares) / reallocationBatch.withdrawnReallocationShares;
                    vaultWithdrawnReceivedLeft[i] = vaultWithdrawnReceived[i];
                    // substract the shares withdrawn from in the reallocation
                    vault.shares -= uint128(vaultWithdrawnReallocationShares);
                }
                
                vault.withdrawnReallocationShares = 0;
            }
        }

        // calculate how the withdrawn amount was deposited to the depositing strategies
        // uint256 vaultWithdrawnReceivedLeft = totalVaultWithdrawnReceived;
        uint256 lastDepositStratIndex = depositStratsCount - 1;
        for (uint256 i; i < depositStratsCount; i++) {
            Strategy storage depositStrategy = strategies[depositStrats[i]];
            Vault storage depositVault = depositStrategy.vaults[msg.sender];
            BatchReallocation storage reallocationBatch = depositStrategy.reallocationBatches[index];
            if (reallocationBatch.depositedReallocation > 0) {
                // calculate reallocation strat deposit amount
                
                // if the strategy is last among the depositing ones, use the amount left to calculate the new shares
                // (same pattern was used when distributing the withdrawn shares to the depositing strategies - last strategy got what was left of shares)
                uint256 depositAmount;
                if (i < lastDepositStratIndex) {
                    for (uint256 j; j < withdrawStrats.length; j++) {
                        uint256 depositAmountFromStrat = (vaultWithdrawnReceived[j] * depositProps[i]) / FULL_PERCENT;
                        depositAmount += depositAmountFromStrat;
                        vaultWithdrawnReceivedLeft[j] -= depositAmountFromStrat;                        
                    }
                } else { // if strat is last, use deposit left
                    for (uint256 j; j < withdrawStrats.length; j++) {
                        depositAmount += vaultWithdrawnReceivedLeft[j];
                    }
                }

                // based on calculated deposited amount calculate/redeem the new strategy shares belonging to a vault
                uint128 newShares;
                if (depositAmount < reallocationBatch.depositedReallocation) {
                    newShares = uint128(reallocationBatch.depositedReallocationSharesReceived * depositAmount / reallocationBatch.depositedReallocation);
                    
                    unchecked {
                        reallocationBatch.depositedReallocationSharesReceived -= newShares;
                        reallocationBatch.depositedReallocation -= uint128(depositAmount); 
                    }
                } else {
                    newShares = reallocationBatch.depositedReallocationSharesReceived;
                    reallocationBatch.depositedReallocationSharesReceived = 0;
                    reallocationBatch.depositedReallocation = 0;
                }
                
                depositVault.shares += newShares;
            }
        }
    }

    /* ========== FAST WITHDRAW ========== */

    /**
     * @notice Instantly withdraw shares from a strategy and return recieved underlying tokens.
     * @dev
     * User can execute the withdrawal of his shares from the vault at any time (except when
     * the reallocation is pending) without waiting for the DHW to process it. This is done
     * independently of other events. The gas cost is paid entirely by the user.
     * Withdrawn amount is sent back to the caller (FastWithdraw) contract, that later on,
     * sends it to a user.
     *
     * Requirements:
     *
     * - the caller must be a fast withdraw contract
     * - strategy shouldn't be removed
     *
     * @param strat Strategy address
     * @param underlying Address of underlying asset
     * @param shares Amount of shares to withdraw
     * @param slippages Strategy slippage values verifying the validity of the strategy state
     * @param swapData Array containig data to swap unclaimed strategy reward tokens for underlying asset
     * @return Withdrawn Underlying asset withdrarn amount
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
     * Called by the vault when a user requested a fast withdraw
     * These shares are either withdrawn from the strategies immidiately or
     * stored as user-strategy shares in the FastWithdraw contract.
     *
     * Requirements:
     *
     * - can only be called by the vault
     *
     * @param vaultStrategies Array of strategy addresses
     * @param vaultProportion Proportion of all vault-strategy shares a vault wants to remove, denoted in basis points (10_000 is 100%)
     * @return Array of removed shares per strategy
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

        for (uint256 i; i < vaultStrategies.length; i++) {
            _notRemoved(vaultStrategies[i]);
            Strategy storage strategy = strategies[vaultStrategies[i]];

            Vault storage vault = strategy.vaults[msg.sender];

            uint128 sharesToWithdraw = Math.getProportion128(vault.shares, vaultProportion, ACCURACY);

            removedShares[i] = sharesToWithdraw;
            vault.shares -= sharesToWithdraw;
        }
        
        return removedShares;
    }
}