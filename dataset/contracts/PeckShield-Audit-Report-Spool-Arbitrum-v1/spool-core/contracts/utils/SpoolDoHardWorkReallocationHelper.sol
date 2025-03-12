// FOR TESTING PURPOSES ONLY. Will NOT be used in production.

// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

// extends
import "./SpoolStrategyHelper.sol";

struct ReallocationWithdrawDataHelper {
    uint256[][] reallocationTable;
    RewardSlippagesHelper[] rewardSlippages;
    uint256[] stratIndexes;
}

/// @notice Containig information if and how to swap strategy rewards at the DHW
/// @dev Passed in by the do-hard-worker
struct RewardSlippagesHelper {
    bool doClaim;
    SwapData[] swapData;
}

/// @notice Strategy reallocation values after reallocation optimization of shares was calculated 
struct ReallocationSharesHelper {
    uint128[] optimizedWithdraws;
    uint128[] optimizedShares;
    uint128[] totalSharesWithdrawn;
}

/// @notice Helper struct to compare strategy share between eachother
/// @dev Used for reallocation optimization of shares (strategy matching deposits and withdrawals between eachother when reallocating)
struct PriceDataHelper {
    uint128 totalValue;
    uint128 totalShares;
}

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
contract SpoolDoHardWorkReallocationHelper is SpoolStrategyHelper {

    constructor (IStrategyRegistry _strategyRegistry) SpoolStrategyHelper(_strategyRegistry) {}

    /**
     * @notice Executes do hard work of specified strategies if reallocation is in progress.
     * @param withdrawData Reallocation values addressing withdrawal part of the reallocation DHW
     * @param allStrategies Array of all strategy addresses in the system for current set reallocation
     */
    function batchDoHardWorkReallocationHelper(
        ReallocationWithdrawDataHelper calldata withdrawData,
        address[] calldata allStrategies
    ) external returns (uint256[] memory) {
        PriceDataHelper[] memory spotPrices = _getPriceData(withdrawData, allStrategies);

        // process the withdraw part of the reallocation
        // process the deposit and the withdrawal part of the users deposits/withdrawals
        return _processWithdraw(
            withdrawData,
            spotPrices
        );
    }

    /**
      * @notice Executes user process and withdraw part of the do-hard-work for the specified strategies when reallocation is in progress.
      * @param withdrawData Reallocation values addressing withdrawal part of the reallocation DHW
      * @param spotPrices current strategy share price data, used to calculate the amount that can me matched between 2 strategies when reallcating
      */
    function _processWithdraw(
        ReallocationWithdrawDataHelper calldata withdrawData,
        PriceDataHelper[] memory spotPrices
    ) private pure returns (uint256[] memory) {
        // go over reallocation table and calculate what amount of shares can be optimized when reallocating
        // we can optimize if two strategies deposit into eachother. With the `spotPrices` we can compare the strategy values.
        ReallocationSharesHelper memory reallocation = _optimizeReallocation(withdrawData, spotPrices);

        uint256[] memory sharesToWithdraw = new uint256[](withdrawData.stratIndexes.length);

        // go over withdrawals
        for (uint256 i = 0; i < withdrawData.stratIndexes.length; i++) {
            uint256 stratIndex = withdrawData.stratIndexes[i];

            sharesToWithdraw[i] = reallocation.totalSharesWithdrawn[stratIndex] - reallocation.optimizedShares[stratIndex];
        }

        return sharesToWithdraw;
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
     * @param priceData An array of price data (see PriceDataHelper)
     * @return reallocationShares Containing arrays showing the optimized share and underlying token amounts
     */
    function _optimizeReallocation(
        ReallocationWithdrawDataHelper calldata withdrawData,
        PriceDataHelper[] memory priceData
    ) private pure returns (ReallocationSharesHelper memory) {
        // amount of optimized collateral amount for each strategy
        uint128[] memory optimizedWithdraws = new uint128[](withdrawData.reallocationTable.length);
        // amount of optimized shares for each strategy
        uint128[] memory optimizedShares = new uint128[](withdrawData.reallocationTable.length);
        // total non-optimized amount of shares for each strategy
        uint128[] memory totalShares = new uint128[](withdrawData.reallocationTable.length);
        
        // go over all the strategies (over reallcation table)
        for (uint128 i = 0; i < withdrawData.reallocationTable.length; i++) {
            for (uint128 j = i + 1; j < withdrawData.reallocationTable.length; j++) {
                // check if both strategies are depositing to eachother, if yes - optimize
                if (withdrawData.reallocationTable[i][j] > 0 && withdrawData.reallocationTable[j][i] > 0) {
                    // calculate strategy I underlying collateral amout withdrawing
                    uint128 amountI = uint128(withdrawData.reallocationTable[i][j] * priceData[i].totalValue / priceData[i].totalShares);
                    // calculate strategy I underlying collateral amout withdrawing
                    uint128 amountJ = uint128(withdrawData.reallocationTable[j][i] * priceData[j].totalValue / priceData[j].totalShares);

                    uint128 optimizedAmount;
                    
                    // check which strategy is withdrawing less
                    if (amountI > amountJ) {
                        optimizedAmount = amountJ;
                    } else {
                        optimizedAmount = amountI;
                    }
                    
                    // use the lesser value of both to save maximum possible optimized amount withdrawing
                    optimizedWithdraws[i] += optimizedAmount;
                    optimizedWithdraws[j] += optimizedAmount;
                }

                // sum total shares withdrawing for each strategy
                unchecked {
                    totalShares[i] += uint128(withdrawData.reallocationTable[i][j]);
                    totalShares[j] += uint128(withdrawData.reallocationTable[j][i]);
                }
            }

            // If we optimized for a strategy, calculate the total shares optimized back from the collateral amount.
            // The optimized shares amount will never be withdrawn from the strategy, as we know other strategies are
            // depositing to the strategy in the equal amount and we know how to mach them.
            if (optimizedWithdraws[i] > 0) {
                optimizedShares[i] = Math.getProportion128(optimizedWithdraws[i], priceData[i].totalShares, priceData[i].totalValue);
            }
        }

        ReallocationSharesHelper memory reallocationShares = ReallocationSharesHelper(
            optimizedWithdraws,
            optimizedShares,
            totalShares
        );
        
        return reallocationShares;
    }

    /**
     * @notice Get urrent strategy price data, containing total balance and total shares
     * @dev Also verify if the total strategy value is according to the defined values
     *
     * @param withdrawData Withdraw data (see WithdrawData)
     * @param allStrategies Array of strategy addresses
     * @return Price data (see PriceDataHelper)
     */
    function _getPriceData(
        ReallocationWithdrawDataHelper calldata withdrawData,
        address[] calldata allStrategies
    ) private returns(PriceDataHelper[] memory) {
        PriceDataHelper[] memory spotPrices = new PriceDataHelper[](allStrategies.length);

        for (uint128 i = 0; i < allStrategies.length; i++) {
            // claim rewards before getting the price
            if (withdrawData.rewardSlippages[i].doClaim) {
                _claimRewards(allStrategies[i], withdrawData.rewardSlippages[i].swapData);
            }
            
            for (uint128 j = 0; j < allStrategies.length; j++) {
                // if a strategy is withdrawing in reallocation get its spot price
                if (withdrawData.reallocationTable[i][j] > 0) {
                    // if strategy is removed treat it's value as 0
                    if (!strategies[allStrategies[i]].isRemoved) {
                        spotPrices[i].totalValue = _getStratValue(allStrategies[i]);
                    }

                    spotPrices[i].totalShares = strategies[allStrategies[i]].totalShares;
                
                    break;
                }
            }
        }

        return spotPrices;
    }
}
