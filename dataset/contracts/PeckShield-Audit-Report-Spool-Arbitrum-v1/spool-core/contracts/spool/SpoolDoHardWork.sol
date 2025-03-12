// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

// extends
import "../interfaces/spool/ISpoolDoHardWork.sol";
import "./SpoolStrategy.sol";

/**
 * @notice Spool part of implementation dealing with the do hard work
 *
 * @dev
 * Do hard work is the process of interacting with other protocols.
 * This process aggregates many actions together to act in as optimized
 * manner as possible. It optimizes for underlying assets and gas cost.
 *
 * Do hard work (DHW) is executed periodically. As users are depositing
 * and withdrawing, these actions are stored in the buffer system.
 * When executed the deposits and withdrawals are matched against
 * eachother to minimize slippage and protocol fees. This means that
 * for a normal DHW only deposit or withdrawal is executed and never
 * both in the same index. Both can only be if the DHW is processing
 * the reallocation as well.
 *
 * Each strategy DHW is executed once per index and then incremented.
 * When all strategies are incremented to the same index, the batch
 * is considered complete. As soon as a new batch starts (first strategy
 * in the new batch is processed) global index is incremented.
 *
 * Global index is always one more or equal to the strategy index.
 * This constraints the system so that all strategy DHWs have to be
 * executed to complete the batch.
 *
 * Do hard work can only be executed by the whitelisted addresses.
 * The whitelisting can be done only by the Spool DAO.
 *
 * Do hard work actions:
 * - deposit
 * - withdrawal
 * - compound rewards
 * - reallocate assets across protocols
 *
 */
abstract contract SpoolDoHardWork is ISpoolDoHardWork, SpoolStrategy {

    /* ========== DO HARD WORK ========== */

    /**
     * @notice Executes do hard work of specified strategies.
     * 
     * @dev
     * Requirements:
     *
     * - caller must be a valid do hard worker
     * - provided strategies must be valid
     * - reallocation is not pending for current index
     * - if `forceOneTxDoHardWork` flag is true all strategies should be executed in one transaction
     * - at least one strategy must be processed
     * - the system should not be paused
     *
     * @param stratIndexes Array of strategy indexes
     * @param slippages Array of slippage values to be used when depositing into protocols (e.g. minOut)
     * @param rewardSlippages Array of values containing information of if and how to swap reward tokens to strategy underlying
     * @param allStrategies Array of all valid strategy addresses in the system
     */
    function batchDoHardWork(
        uint256[] memory stratIndexes,
        uint256[][] memory slippages,
        RewardSlippages[] memory rewardSlippages,
        address[] memory allStrategies
    ) 
        external
        systemNotPaused
        onlyDoHardWorker
        verifyStrategies(allStrategies)
    {
        // update global index if this are first strategies in index
        if (_isBatchComplete()) {
            globalIndex++;
            doHardWorksLeft = uint8(allStrategies.length);
        }

        // verify reallocation is not set for the current index
        if (reallocationIndex == globalIndex) {
            // if reallocation is set, verify it was disabled
            require(reallocationTableHash == 0, "RLC");
            // if yes, reset reallocation index
            reallocationIndex = 0;
        }

        require(
            stratIndexes.length > 0 &&
            stratIndexes.length == slippages.length &&
            stratIndexes.length == rewardSlippages.length,
            "BIPT"
        );

        // check if DHW is forced to be executed in one transaction
        if (forceOneTxDoHardWork) {
            require(stratIndexes.length == allStrategies.length, "1TX");
        }

        // go over withdrawals and deposits
        for (uint256 i = 0; i < stratIndexes.length; i++) {
            address stratAddress = allStrategies[stratIndexes[i]];
            _doHardWork(stratAddress, slippages[i], rewardSlippages[i]);
            _updatePending(stratAddress);
            _finishStrategyDoHardWork(stratAddress);  
            allStrategies[stratIndexes[i]] = address(0);
        }
        
        // set total underlying for remaining strategies.
        // ignore this section if all strategies have already been processed.
        if(!forceOneTxDoHardWork){
            for (uint256 i = 0; i < stratIndexes.length; i++) {
                address strat = allStrategies[i];
                if(strat != address(0)) {
                    Strategy storage strategy = strategies[strat];
                    uint processingIndex = strategy.index + 1;
                    strategy.totalUnderlying[processingIndex].amount = _totalUnderlying(strat);
                }
            }
        }

        _updateDoHardWorksLeft(stratIndexes.length);

        // if DHW for index finished
        _finishDhw(false);
    }

    /**
     * @notice Process strategy DHW, deposit wnd withdraw
     * @dev Only executed when there is no reallocation for the DHW
     * @param strat Strategy address
     * @param slippages Array of slippage values to be used when depositing into protocols (e.g. minOut)
     * @param rewardSlippages Array of values containing information of if and how to swap reward tokens to strategy underlying
     */
    function _doHardWork(
        address strat,
        uint256[] memory slippages,
        RewardSlippages memory rewardSlippages
    ) private {
        Strategy storage strategy = strategies[strat];

        // Check if strategy wasn't exected in current index yet
        require(strategy.index < globalIndex, "SFIN");

        _process(strat, slippages, rewardSlippages.doClaim, rewardSlippages.swapData);
    }

    /* ========== DO HARD WORK when REALLOCATING ========== */

    /**
     * @notice Executes do hard work of specified strategies if reallocation is in progress.
     * 
     * @dev
     * Requirements:
     *
     * - caller must be a valid do hard worker
     * - provided strategies must be valid
     * - reallocation is pending for current index
     * - at least one strategy must be processed
     * - the system should not be paused
     *
     * @param withdrawData Reallocation values addressing withdrawal part of the reallocation DHW
     * @param depositData Reallocation values addressing deposit part of the reallocation DHW
     * @param allStrategies Array of all strategy addresses in the system for current set reallocation
     * @param isOneTransaction Flag denoting if the DHW should execute in one transaction
     */
    function batchDoHardWorkReallocation(
        ReallocationWithdrawData memory withdrawData,
        ReallocationData memory depositData,
        address[] memory allStrategies,
        bool isOneTransaction
    ) external systemNotPaused onlyDoHardWorker verifyReallocationStrategies(allStrategies) {
        if (_isBatchComplete()) {
            globalIndex++;
            
            doHardWorksLeft = uint8(allStrategies.length);
            withdrawalDoHardWorksLeft = uint8(allStrategies.length);
        }

        // verify reallocation is set for the current index, and not disabled
        require(
            reallocationIndex == globalIndex &&
            reallocationTableHash != 0,
            "XNRLC"
        );

        // add all indexes if DHW is in one transaction
        if (isOneTransaction) {
            require(
                    withdrawData.stratIndexes.length == allStrategies.length &&
                    depositData.stratIndexes.length == allStrategies.length,
                    "1TX"
                );
        } else {
            require(!forceOneTxDoHardWork, "F1TX");
            
            require(withdrawData.stratIndexes.length > 0 || depositData.stratIndexes.length > 0, "NOSTR");
        }

        // execute deposits and withdrawals
        _batchDoHardWorkReallocation(withdrawData, depositData, allStrategies);

        // update if DHW for index finished
        _finishDhw(true);
    }

    /**
     * @notice Executes do hard work of specified strategies if reallocation is in progress.
     * @param withdrawData Reallocation values addressing withdrawal part of the reallocation DHW
     * @param depositData Reallocation values addressing deposit part of the reallocation DHW
     * @param allStrategies Array of all strategy addresses in the system for current set reallocation
     */
    function _batchDoHardWorkReallocation(
        ReallocationWithdrawData memory withdrawData,
        ReallocationData memory depositData,
        address[] memory allStrategies
    ) private {
        // WITHDRAWALS
        // reallocation withdraw
        // process users deposit and withdrawals
        if (withdrawData.stratIndexes.length > 0) {
            // check parameters
            require(
                withdrawData.stratIndexes.length == withdrawData.slippages.length && 
                withdrawalDoHardWorksLeft >= withdrawData.stratIndexes.length,
                "BWI"
            );
            
            // verify if reallocation table matches the reallocationtable hash
            _verifyReallocationTable(withdrawData.reallocationTable);

            // get current strategy price data
            // this is later used to calculate the amount that can me matched
            // between 2 strategies when they deposit in eachother
            PriceData[] memory spotPrices = _getPriceData(withdrawData, allStrategies);

            // process the withdraw part of the reallocation
            // process the deposit and the withdrawal part of the users deposits/withdrawals
            _processWithdraw(
                withdrawData,
                allStrategies,
                spotPrices
            );

            // update number of strategies needing to be processed for the current reallocation DHW
            // can continue to deposit only when it reaches 0
            _updateWithdrawalDohardWorksleft(withdrawData.stratIndexes.length);
        }

        // check if withdrawal phase was finished before starting deposit
        require(
            !(depositData.stratIndexes.length > 0 && withdrawalDoHardWorksLeft > 0),
            "WNF"
        );

        // DEPOSITS
        // deposit reallocated amounts withdrawn above into strategies
        if (depositData.stratIndexes.length > 0) {
            // check parameters
            require(
                doHardWorksLeft >= depositData.stratIndexes.length &&
                depositData.stratIndexes.length == depositData.slippages.length,
                "BDI"
            );

            // deposit reallocated amounts into strategies
            // this only deals with the reallocated amounts as users were already processed in the withdrawal phase
            for (uint256 i = 0; i < depositData.stratIndexes.length; i++) {
                uint256 stratIndex = depositData.stratIndexes[i];
                address stratAddress = allStrategies[stratIndex];
                Strategy storage strategy = strategies[stratAddress];

                // verify the strategy was not removed (it could be removed in the middle of the DHW if the DHW was executed in multiple transactions)
                _notRemoved(stratAddress);
                require(strategy.isInDepositPhase, "SWNP");

                // deposit reallocation withdrawn amounts according to the calculations
                _doHardWorkDeposit(stratAddress, depositData.slippages[stratIndex]);
                // mark strategy as finished for the current index
                _finishStrategyDoHardWork(stratAddress);

                // remove the flag indicating strategy should deposit reallocated amount
                strategy.isInDepositPhase = false;
            }
            
            // update number of strategies left in the current index
            // if this reaches 0, DHW is considered complete
            _updateDoHardWorksLeft(depositData.stratIndexes.length);
        }
    }

    /**
      * @notice Executes user process and withdraw part of the do-hard-work for the specified strategies when reallocation is in progress.
      * @param withdrawData Reallocation values addressing withdrawal part of the reallocation DHW
      * @param allStrategies Array of all strategy addresses in the system for current set reallocation
      * @param spotPrices current strategy share price data, used to calculate the amount that can me matched between 2 strategies when reallcating
      */
    function _processWithdraw(
        ReallocationWithdrawData memory withdrawData,
        address[] memory allStrategies,
        PriceData[] memory spotPrices
    ) private {
        // go over reallocation table and calculate what amount of shares can be optimized when reallocating
        // we can optimize if two strategies deposit into eachother. With the `spotPrices` we can compare the strategy values.
        ReallocationShares memory reallocation = _optimizeReallocation(withdrawData, spotPrices);

        // go over withdrawals
        for (uint256 i = 0; i < withdrawData.stratIndexes.length; i++) {
            uint256 stratIndex = withdrawData.stratIndexes[i];
            address stratAddress = allStrategies[stratIndex];
            Strategy storage strategy = strategies[stratAddress];
            _notRemoved(stratAddress);
            require(!strategy.isInDepositPhase, "SWP");

            uint128 withdrawnReallocationReceived;
            {
                uint128 sharesToWithdraw = reallocation.totalSharesWithdrawn[stratIndex] - reallocation.optimizedShares[stratIndex];

                ProcessReallocationData memory processReallocationData = ProcessReallocationData(
                    sharesToWithdraw,
                    reallocation.optimizedShares[stratIndex],
                    reallocation.optimizedWithdraws[stratIndex]
                );
                
                // withdraw reallocation / returns non-optimized withdrawn amount
                withdrawnReallocationReceived = _doHardWorkReallocation(stratAddress, withdrawData.slippages[stratIndex], processReallocationData);
            }

            // reallocate withdrawn to other strategies
            if (reallocation.totalSharesWithdrawn[stratIndex] > 0) {
                _depositReallocatedAmount(
                    stratIndex,
                    withdrawnReallocationReceived,
                    allStrategies,
                    withdrawData.reallocationTable[stratIndex],
                    reallocation
                );
            }           

            _updatePending(stratAddress);

            strategy.isInDepositPhase = true;
        }
    }

    /**
     * @notice Process strategy DHW, including reallocation 
     * @dev Only executed when reallocation is set for the DHW
     * @param strat Strategy address
     * @param slippages Array of slippage values
     * @param processReallocationData Reallocation data (see ProcessReallocationData)
     * @return Received withdrawn reallocation
     */
    function _doHardWorkReallocation(
        address strat,
        uint256[] memory slippages,
        ProcessReallocationData memory processReallocationData
    ) private returns(uint128){
        Strategy storage strategy = strategies[strat];

        // Check if strategy wasn't exected in current index yet
        require(strategy.index < globalIndex, "SFIN");

        uint128 withdrawnReallocationReceived = _processReallocation(strat, slippages, processReallocationData);

        return withdrawnReallocationReceived;
    }

    /**
     * @notice Process deposit collected form the reallocation
     * @dev Only executed when reallocation is set for the DHW
     * @param strat Strategy address
     * @param slippages Array of slippage values
     */
    function _doHardWorkDeposit(
        address strat,
        uint256[] memory slippages
    ) private {
        _processDeposit(strat, slippages);
    }

    /**
     * @notice Calculate amount of shares that can be swapped between a pair of strategies (without withdrawing from the protocols)
     *
     * @dev This is done to ensure only the necessary amoun gets withdrawn from protocols and lower the total slippage and fee.
     * NOTE: We know strategies depositing into eachother must have the same underlying asset
     * The underlying asset is used to compare the amount ob both strategies withdrawing (depositing) into eachother. 
     *
     * Returns:
     * - amount of optimized collateral amount for each strategy
     * - amount of optimized shares for each strategy
     * - total non-optimized amount of shares for each strategy
     *
     * @param withdrawData Withdraw data (see WithdrawData)
     * @param priceData An array of price data (see PriceData)
     * @return reallocationShares Containing arrays showing the optimized share and underlying token amounts
     */
    function _optimizeReallocation(
        ReallocationWithdrawData memory withdrawData,
        PriceData[] memory priceData
    ) private pure returns (ReallocationShares memory) {
        // amount of optimized collateral amount for each strategy
        uint128[] memory optimizedWithdraws = new uint128[](withdrawData.reallocationTable.length);
        // amount of optimized shares for each strategy
        uint128[] memory optimizedShares = new uint128[](withdrawData.reallocationTable.length);
        // total non-optimized amount of shares for each strategy
        uint128[] memory totalShares = new uint128[](withdrawData.reallocationTable.length);
        
        uint256[][] memory optimizedReallocationTable = new uint256[][](withdrawData.reallocationTable.length);

        for (uint256 i = 0; i < withdrawData.reallocationTable.length; i++) {
            optimizedReallocationTable[i] = new uint256[](withdrawData.reallocationTable.length);
        }
        
        // go over all the strategies (over reallcation table)
        for (uint256 i = 0; i < withdrawData.reallocationTable.length; i++) {
            for (uint256 j = i + 1; j < withdrawData.reallocationTable.length; j++) {
                // check if both strategies are depositing to eachother, if yes - optimize
                if (withdrawData.reallocationTable[i][j] > 0 && withdrawData.reallocationTable[j][i] > 0) {
                    // calculate strategy I underlying collateral amount withdrawing
                    uint256 amountI = withdrawData.reallocationTable[i][j] * priceData[i].totalValue / priceData[i].totalShares;
                    // calculate strategy J underlying collateral amount withdrawing
                    uint256 amountJ = withdrawData.reallocationTable[j][i] * priceData[j].totalValue / priceData[j].totalShares;

                    uint256 optimizedAmount;
                    
                    // check which strategy is withdrawing less
                    if (amountI > amountJ) {
                        optimizedAmount = amountJ;
                    } else {
                        optimizedAmount = amountI;
                    }
                    
                    // use the lesser value of both to save maximum possible optimized amount withdrawing
                    optimizedWithdraws[i] += uint128(optimizedAmount);
                    optimizedWithdraws[j] += uint128(optimizedAmount);

                    unchecked {
                        // If we optimized for a strategy, calculate the total shares optimized back from the collateral amount.
                        // The optimized shares amount will never be withdrawn from the strategy, as we know other strategies are
                        // depositing to the strategy in the equal amount and we know how to mach them.
                        optimizedReallocationTable[i][j] = optimizedAmount * priceData[i].totalShares / priceData[i].totalValue;
                        optimizedReallocationTable[j][i] = optimizedAmount * priceData[j].totalShares / priceData[j].totalValue;

                        optimizedShares[i] += uint128(optimizedReallocationTable[i][j]);
                        optimizedShares[j] += uint128(optimizedReallocationTable[j][i]);
                    }
                }

                // sum total shares withdrawing for each strategy
                unchecked {
                    totalShares[i] += uint128(withdrawData.reallocationTable[i][j]);
                    totalShares[j] += uint128(withdrawData.reallocationTable[j][i]);
                }
            }
        }

        ReallocationShares memory reallocationShares = ReallocationShares(
            optimizedWithdraws,
            optimizedShares,
            totalShares,
            optimizedReallocationTable
        );
        
        return reallocationShares;
    }

    /**
     * @notice Get urrent strategy price data, containing total balance and total shares
     * @dev Also verify if the total strategy value is according to the defined values
     *
     * @param withdrawData Withdraw data (see WithdrawData)
     * @param allStrategies Array of strategy addresses
     * @return Price data (see PriceData)
     */
    function _getPriceData(
        ReallocationWithdrawData memory withdrawData,
        address[] memory allStrategies
    ) private returns(PriceData[] memory) {
        PriceData[] memory spotPrices = new PriceData[](allStrategies.length);

        for (uint256 i = 0; i < allStrategies.length; i++) {
            // claim rewards before getting the price
            if (withdrawData.rewardSlippages[i].doClaim) {
                _claimRewards(allStrategies[i], withdrawData.rewardSlippages[i].swapData);
            }
            
            for (uint256 j = 0; j < allStrategies.length; j++) {
                // if a strategy is withdrawing in reallocation get its spot price
                if (withdrawData.reallocationTable[i][j] > 0) {
                    // if strategy is removed treat it's value as 0
                    if (!strategies[allStrategies[i]].isRemoved) {
                        spotPrices[i].totalValue = _getStratValue(allStrategies[i]);
                    }

                    spotPrices[i].totalShares = strategies[allStrategies[i]].totalShares;

                    require(
                        spotPrices[i].totalValue >= withdrawData.priceSlippages[i].min &&
                        spotPrices[i].totalValue <= withdrawData.priceSlippages[i].max,
                        "BPRC"
                    );
                
                    break;
                }
            }
        }

        return spotPrices;
    }

    /**
      * @notice Processes reallocated amount deposits.
      * @dev Deposits withdrawn optimized and non-optimized amounts to the according strategies
      * @param stratIndex Index of the reallocating (wtihdrawing) strategy
      * @param withdrawnReallocationReceived Actual received withdrawn reallocation
      * @param _strategies Array of all system strategy addresses
      * @param stratReallocationShares Array of strategy reallocation shares do deposit to
      * @param reallocation Reallocation share values
      */
    function _depositReallocatedAmount(
        uint256 stratIndex,
        uint128 withdrawnReallocationReceived,
        address[] memory _strategies,
        uint256[] memory stratReallocationShares,
        ReallocationShares memory reallocation
    ) private {
        uint128 optimizedWithdraw = reallocation.optimizedWithdraws[stratIndex];
        uint128 optimizedShares = reallocation.optimizedShares[stratIndex];
        uint256[] memory stratOptimizedReallocationShares = reallocation.optimizedReallocationTable[stratIndex];

        uint256 nonOptimizedTotalWithdrawnShares = reallocation.totalSharesWithdrawn[stratIndex] - optimizedShares;
        for (uint256 i = 0; i < stratReallocationShares.length; i++) {
            if (stratReallocationShares[i] > 0) {
                Strategy storage depositStrategy = strategies[_strategies[i]];

                uint256 nonOptimizedWithdrawnShares = stratReallocationShares[i] - stratOptimizedReallocationShares[i];

                // add actual withdrawn deposit
                depositStrategy.pendingReallocateAverageDeposit +=
                    Math.getProportion128(withdrawnReallocationReceived + optimizedWithdraw, stratReallocationShares[i], reallocation.totalSharesWithdrawn[stratIndex]);
                
                if (nonOptimizedWithdrawnShares > 0 && nonOptimizedTotalWithdrawnShares > 0) {
                    // add actual withdrawn deposit
                    depositStrategy.pendingReallocateDeposit +=
                        Math.getProportion128(withdrawnReallocationReceived, nonOptimizedWithdrawnShares, nonOptimizedTotalWithdrawnShares);
                }

                if (stratOptimizedReallocationShares[i] > 0 && optimizedShares > 0) {
                    // add optimized deposit
                    depositStrategy.pendingReallocateOptimizedDeposit +=
                        Math.getProportion128(optimizedWithdraw, stratOptimizedReallocationShares[i], optimizedShares);
                }
            }
        }
    }

    /* ========== SHARED FUNCTIONS ========== */

    /**
     * @notice After strategy DHW is complete increment strategy index
     * @param strat Strategy address
     */
    function _finishStrategyDoHardWork(address strat) private {
        Strategy storage strategy = strategies[strat];
        
        strategy.index++;

        emit DoHardWorkStrategyCompleted(strat, strategy.index);
    }

    /**
     * @notice After strategy DHW process update strategy pending values
     * @dev set pending next as pending and reset pending next
     * @param strat Strategy address
     */
    function _updatePending(address strat) private {
        Strategy storage strategy = strategies[strat];

        Pending memory pendingUserNext = strategy.pendingUserNext;
        strategy.pendingUser = pendingUserNext;
        
        if (
            pendingUserNext.deposit != Max128Bit.ZERO || 
            pendingUserNext.sharesToWithdraw != Max128Bit.ZERO
        ) {
            strategy.pendingUserNext = Pending(Max128Bit.ZERO, Max128Bit.ZERO);
        }
    }

    /**
     * @notice Update the number of "do hard work" processes left.
     * @param processedCount Number of completed actions
     */
    function _updateDoHardWorksLeft(uint256 processedCount) private {
        doHardWorksLeft -= uint8(processedCount);
    }

    /**
     * @notice Update the number of "withdrawal do hard work" processes left.
     * @param processedCount Number of completed actions
     */
    function _updateWithdrawalDohardWorksleft(uint256 processedCount) private {
        withdrawalDoHardWorksLeft -= uint8(processedCount);
    }

    /**
     * @notice Hash a reallocation table after it was updated
     * @param reallocationTable 2D table showing amount of shares withdrawing to each strategy
     */
    function _hashReallocationTable(uint256[][] memory reallocationTable) internal {
        reallocationTableHash = Hash.hashReallocationTable(reallocationTable);
        if (logReallocationTable) {
            // this is only meant to be emitted when debugging
            emit ReallocationTableUpdatedWithTable(reallocationIndex, reallocationTableHash, reallocationTable);
        } else {
            emit ReallocationTableUpdated(reallocationIndex, reallocationTableHash);
        }
    }

    /**
     * @notice Calculate and store the hash of the given strategy array
     * @param strategies Strategy addresses to hash
     */
    function _hashReallocationStrategies(address[] memory strategies) internal {
        reallocationStrategiesHash = Hash.hashStrategies(strategies);
    }
}
