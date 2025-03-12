// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../interfaces/IAssetGroupRegistry.sol";
import "../interfaces/IMasterWallet.sol";
import "../interfaces/IUsdPriceFeedManager.sol";
import "../interfaces/CommonErrors.sol";
import "./ArrayMapping.sol";
import "./SpoolUtils.sol";
import "./uint16a16Lib.sol";

/**
 * @notice Parameters for reallocation.
 * @custom:member assetGroupRegistry Asset group registry contract.
 * @custom:member priceFeedManager Price feed manager contract.
 * @custom:member masterWallet Master wallet contract.
 * @custom:member assetGroupId ID of the asset group used by strategies being reallocated.
 * @custom:member swapInfo Information for swapping assets before depositing into the protocol.
 * @custom:member depositSlippages Slippages used to constrain depositing into the protocol.
 * @custom:member withdrawalSlippages Slippages used to contrain withdrawal from the protocol.
 * @custom:member exchangeRateSlippages Slippages used to constratrain exchange rates for asset tokens.
 */
struct ReallocationParameterBag {
    IAssetGroupRegistry assetGroupRegistry;
    IUsdPriceFeedManager priceFeedManager;
    IMasterWallet masterWallet;
    uint256 assetGroupId;
    SwapInfo[][] swapInfo;
    uint256[][] depositSlippages;
    uint256[][] withdrawalSlippages;
    uint256[2][] exchangeRateSlippages;
}

library ReallocationLib {
    using uint16a16Lib for uint16a16;
    using ArrayMappingUint256 for mapping(uint256 => uint256);
    using ArrayMappingAddress for mapping(uint256 => address);

    /**
     * @notice Reallocates smart vaults.
     * @param smartVaults Smart vaults to reallocate.
     * @param strategies Set of strategies involved in the reallocation.
     * @param reallocationParams Bag with reallocation parameters.
     * @param _smartVaultStrategies Strategies per smart vault.
     * @param _smartVaultAllocations Allocations per smart vault.
     */
    function reallocate(
        address[] calldata smartVaults,
        address[] calldata strategies,
        ReallocationParameterBag calldata reallocationParams,
        mapping(address => address[]) storage _smartVaultStrategies,
        mapping(address => uint16a16) storage _smartVaultAllocations
    ) public {
        // Validate provided strategies and create a per smart vault strategy mapping.
        uint256[][] memory strategyMapping = mapStrategies(smartVaults, strategies, _smartVaultStrategies);

        // Calculate reallocations needed for smart vaults.
        uint256[][][] memory reallocations = new uint256[][][](smartVaults.length);
        for (uint256 i; i < smartVaults.length; ++i) {
            reallocations[i] =
                calculateReallocation(smartVaults[i], _smartVaultStrategies[smartVaults[i]], _smartVaultAllocations);
        }

        // Build the strategy-to-strategy reallocation table.
        uint256[][][] memory reallocationTable =
            buildReallocationTable(strategyMapping, strategies.length, reallocations);

        // Do the actual reallocation with withdrawals from and deposits into the underlying protocols.
        doReallocation(strategies, reallocationParams, reallocationTable);

        // Smart vaults claim strategy shares.
        claimShares(smartVaults, strategies, strategyMapping, reallocationTable, reallocations);
    }

    /**
     * @dev Creates a mapping between strategies of smart vaults and provided strategies.
     * Also validates that provided strategies form a set of smart vaults' strategies.
     * @param smartVaults Smart vaults to reallocate.
     * @param strategies Set of strategies involved in the reallocation.
     * @param _smartVaultStrategies Strategies per smart vault.
     * @return Mapping between smart vault's strategies and provided strategies:
     * - first index runs over smart vaults
     * - second index runs over strategies of the smart vault.
     * - value represents a position of smart vault's strategy in the provided `strategies` array.
     */
    function mapStrategies(
        address[] calldata smartVaults,
        address[] calldata strategies,
        mapping(address => address[]) storage _smartVaultStrategies
    ) private view returns (uint256[][] memory) {
        // We want to validate that the provided strategies represent a set of all the
        // strategies used by the smart vaults being reallocated. At the same time we
        // also build a mapping between strategies as listed on each smart vault and
        // the provided strategies.

        bool[] memory strategyMatched = new bool[](strategies.length);
        uint256[][] memory strategyMapping = new uint256[][](smartVaults.length);

        // Build a mapping for each smart vault and validate that all strategies are
        // present in the provided list.
        for (uint256 i; i < smartVaults.length; ++i) {
            // Get strategies for this smart vault.
            address[] storage smartVaultStrategies = _smartVaultStrategies[smartVaults[i]];
            uint256 smartVaultStrategiesLength = smartVaultStrategies.length;
            // Mapping from this smart vault's strategies to provided strategies.
            strategyMapping[i] = new uint256[](smartVaultStrategiesLength);

            // Loop over smart vault's strategies.
            for (uint256 j; j < smartVaultStrategiesLength; ++j) {
                address strategy = smartVaultStrategies[j];
                bool found = false;

                // Try to find the strategy in the provided list of strategies.
                for (uint256 k; k < strategies.length; ++k) {
                    if (strategies[k] == strategy) {
                        // Match found.
                        found = true;
                        strategyMatched[k] = true;
                        // Add entry to the strategy mapping.
                        strategyMapping[i][j] = k;

                        break;
                    }
                }

                if (!found) {
                    // If a smart vault's strategy was not found in the provided list
                    // of strategies, this means that the provided list is invalid.
                    revert InvalidStrategies();
                }
            }
        }

        // Validate that each strategy in the provided list was matched at least once.
        for (uint256 i; i < strategyMatched.length; ++i) {
            if (!strategyMatched[i]) {
                // If a strategy was not matched, this means that it is not used by any
                // smart vault and should not be included in the list.
                revert InvalidStrategies();
            }
        }

        return strategyMapping;
    }

    /**
     * @dev Calculates reallocation needed per smart vault.
     * @param smartVault Smart vault.
     * @param smartVaultStrategies Strategies of the smart vault.
     * @param _smartVaultAllocations Allocations per smart vault.
     * @return Reallocation of the smart vault:
     * - first index is 0 or 1
     * - 0:
     *   - second index runs over smart vault's strategies
     *   - value is USD value that needs to be withdrawn from the strategy
     * - 1:
     *   - second index runs over smart vault's strategies + extra field
     *   - value is USD value that needs to be deposited into the strategy
     *   - extra field gathers total value that needs to be deposited by the smart vault
     */
    function calculateReallocation(
        address smartVault,
        address[] storage smartVaultStrategies,
        mapping(address => uint16a16) storage _smartVaultAllocations
    ) private returns (uint256[][] memory) {
        // Store length of strategies array to not read storage every time.
        uint256 smartVaultStrategiesLength = smartVaultStrategies.length;

        // Initialize array for this smart vault.
        uint256[][] memory reallocation = new uint256[][](2);
        reallocation[0] = new uint256[](smartVaultStrategiesLength); // values to redeem
        reallocation[1] = new uint256[](smartVaultStrategiesLength + 1); // values to deposit | total value to deposit

        // Get smart vaults total USD value.
        uint256 totalUsdValue = SpoolUtils.getVaultTotalUsdValue(smartVault, smartVaultStrategies);

        // Get sum total of target allocation.
        uint256 totalTargetAllocation;
        for (uint256 i; i < smartVaultStrategiesLength; ++i) {
            totalTargetAllocation += _smartVaultAllocations[smartVault].get(i);
        }

        // Compare target and current allocation.
        for (uint256 i; i < smartVaultStrategiesLength; ++i) {
            uint256 targetValue = _smartVaultAllocations[smartVault].get(i) * totalUsdValue / totalTargetAllocation;
            uint256 currentValue = SpoolUtils.getVaultStrategyUsdValue(smartVault, smartVaultStrategies[i]);

            if (targetValue > currentValue) {
                // This strategy needs deposit.
                reallocation[1][i] = targetValue - currentValue;
                reallocation[1][smartVaultStrategiesLength] += targetValue - currentValue;
            } else if (targetValue < currentValue) {
                // This strategy needs withdrawal.

                // Relese strategy shares.
                uint256 sharesToRedeem = IStrategy(smartVaultStrategies[i]).balanceOf(smartVault)
                    * (currentValue - targetValue) / currentValue;
                IStrategy(smartVaultStrategies[i]).releaseShares(smartVault, sharesToRedeem);

                // Recalculate value to withdraw based on released shares.
                reallocation[0][i] = IStrategy(smartVaultStrategies[i]).totalUsdValue() * sharesToRedeem
                    / IStrategy(smartVaultStrategies[i]).totalSupply();
            }
        }

        return reallocation;
    }

    /**
     * @dev Builds reallocation table from smart vaults' reallocations.
     * @param strategyMapping Mapping between smart vault's strategies and provided strategies.
     * @param numStrategies Number of all strategies involved in the reallocation.
     * @param reallocations Reallocations needed by each smart vaults.
     * @return Reallocation table:
     * - first index runs over all strategies i
     * - second index runs over all strategies j
     * - third index is 0, 1 or 2
     *   - 0: value represent USD value that should be withdrawn by strategy i and deposited into strategy j
     *   - 1: value is not used yet
     *     - will be used to represent amount of matched shares from strategy j that are distributed to strategy i
     *   - 2: value is not used yet
     *     - will be used to represent amount of unmatched shares from strategy j that are distributed to strategy i
     */
    function buildReallocationTable(
        uint256[][] memory strategyMapping,
        uint256 numStrategies,
        uint256[][][] memory reallocations
    ) private pure returns (uint256[][][] memory) {
        // We want to build a reallocation table which specifies how to redistribute
        // funds from one strategy to another.

        // Reallocation table is numStrategies x numStrategies big.
        // A value of cell (i, j) V_ij specifies the value V that needs to be withdrawn
        // from strategy i and deposited into strategy j.
        uint256[][][] memory reallocationTable = new uint256[][][](numStrategies);
        for (uint256 i; i < numStrategies; ++i) {
            reallocationTable[i] = new uint256[][](numStrategies);

            for (uint256 j; j < numStrategies; ++j) {
                reallocationTable[i][j] = new uint256[](3);
            }
        }

        // Loop over smart vaults.
        for (uint256 i; i < reallocations.length; ++i) {
            // Calculate witdrawals and deposits needed to allign with new allocation.
            uint256 strategiesLength = reallocations[i][0].length;

            // Find strategies that need withdrawal.
            for (uint256 j; j < strategiesLength; ++j) {
                if (reallocations[i][0][j] == 0) {
                    continue;
                }

                uint256[] memory values = new uint256[](2);
                values[0] = reallocations[i][0][j];
                values[1] = reallocations[i][1][strategiesLength];

                // Find strategies that need deposit.
                for (uint256 k; k < strategiesLength; ++k) {
                    if (reallocations[i][1][k] == 0) {
                        continue;
                    }

                    // Find value from j that should move to strategy k.
                    uint256 valueToDeposit = values[0] * reallocations[i][1][k] / values[1];
                    reallocationTable[strategyMapping[i][j]][strategyMapping[i][k]][0] += valueToDeposit;

                    values[0] -= valueToDeposit; // dust-less calculation.
                    values[1] -= reallocations[i][1][k];
                }
            }
        }

        return reallocationTable;
    }

    /**
     * @dev Does the actual reallocation by withdrawing from and depositing into strategies.
     * Also populates the reallocation table.
     * @param strategies Set of strategies involved in the reallocation.
     * @param reallocationParams Bag with reallocation parameters.
     * @param reallocationTable Reallocation table.
     */
    function doReallocation(
        address[] calldata strategies,
        ReallocationParameterBag calldata reallocationParams,
        uint256[][][] memory reallocationTable
    ) private {
        // Get asset group and corresponding exchange rates.
        address[] memory assetGroup =
            reallocationParams.assetGroupRegistry.listAssetGroup(reallocationParams.assetGroupId);

        if (assetGroup.length != reallocationParams.exchangeRateSlippages.length) {
            revert InvalidArrayLength();
        }

        uint256[] memory exchangeRates = SpoolUtils.getExchangeRates(assetGroup, reallocationParams.priceFeedManager);
        for (uint256 i; i < assetGroup.length; ++i) {
            if (
                exchangeRates[i] < reallocationParams.exchangeRateSlippages[i][0]
                    || exchangeRates[i] > reallocationParams.exchangeRateSlippages[i][1]
            ) {
                revert ExchangeRateOutOfSlippages();
            }
        }

        // Will store how much assets each strategy has to deposit.
        uint256[][] memory toDeposit = new uint256[][](strategies.length);
        for (uint256 i; i < strategies.length; ++i) {
            toDeposit[i] = new uint256[](assetGroup.length + 1);
            // toDeposit[0..strategies.length-1]: amount of assets to deposit into strategy i
            // toDeposit[strategies.length]: is there something to deposit
        }

        // Distribute matched shares and withdraw unamatched ones.
        for (uint256 i; i < strategies.length; ++i) {
            // Calculate amount of shares to distribute and amount of shares to redeem.
            uint256 sharesToRedeem;
            uint256 totalUnmatchedWithdrawals;

            {
                uint256[2] memory totals;
                // totals[0] -> total withdrawals
                // totals[1] -> total matched withdrawals

                for (uint256 j; j < strategies.length; ++j) {
                    totals[0] += reallocationTable[i][j][0];

                    // Take smaller for matched withdrawals.
                    if (reallocationTable[i][j][0] > reallocationTable[j][i][0]) {
                        totals[1] += reallocationTable[j][i][0];
                    } else {
                        totals[1] += reallocationTable[i][j][0];
                    }
                }

                // Unmatched withdrawals are difference between total and matched withdrawals.
                totalUnmatchedWithdrawals = totals[0] - totals[1];

                if (totals[0] == 0) {
                    IStrategy(strategies[i]).beforeRedeemalCheck(0, reallocationParams.withdrawalSlippages[i]);

                    // There is nothing to withdraw from strategy i.
                    continue;
                }

                // Calculate amount of shares to redeem and to distribute.
                uint256 sharesToDistribute = // first store here total amount of shares that should have been withdrawn
                 IStrategy(strategies[i]).totalSupply() * totals[0] / IStrategy(strategies[i]).totalUsdValue();

                IStrategy(strategies[i]).beforeRedeemalCheck(
                    sharesToDistribute, reallocationParams.withdrawalSlippages[i]
                );

                sharesToRedeem = sharesToDistribute * (totals[0] - totals[1]) / totals[0];
                sharesToDistribute -= sharesToRedeem;

                // Distribute matched shares to matched strategies.
                if (sharesToDistribute > 0) {
                    for (uint256 j; j < strategies.length; ++j) {
                        uint256 matched;

                        // Take smaller for matched withdrawals.
                        if (reallocationTable[i][j][0] > reallocationTable[j][i][0]) {
                            matched = reallocationTable[j][i][0];
                        } else {
                            matched = reallocationTable[i][j][0];
                        }

                        if (matched == 0) {
                            continue;
                        }

                        // Give shares to strategy j.
                        reallocationTable[j][i][1] = sharesToDistribute * matched / totals[1];

                        sharesToDistribute -= reallocationTable[j][i][1]; // dust-less calculation
                        totals[1] -= matched;
                    }
                }
            }

            if (sharesToRedeem == 0) {
                // There is nothing to withdraw for strategy i.
                continue;
            }

            // Withdraw assets from underlying protocol.
            uint256[] memory withdrawnAssets = IStrategy(strategies[i]).redeemFast(
                sharesToRedeem,
                address(reallocationParams.masterWallet),
                assetGroup,
                exchangeRates,
                reallocationParams.priceFeedManager,
                reallocationParams.withdrawalSlippages[i]
            );

            // Distribute withdrawn assets to strategies according to reallocation table.
            for (uint256 j; j < strategies.length; ++j) {
                if (reallocationTable[i][j][0] <= reallocationTable[j][i][0]) {
                    // Nothing to deposit into strategy j.
                    continue;
                }

                for (uint256 k; k < assetGroup.length; ++k) {
                    // Find out how much of asset k should go to strategy j.
                    uint256 depositAmount = withdrawnAssets[k]
                        * (reallocationTable[i][j][0] - reallocationTable[j][i][0]) / totalUnmatchedWithdrawals;
                    toDeposit[j][k] += depositAmount;
                    // Mark that there is something to deposit for strategy j.
                    toDeposit[j][assetGroup.length] += 1;

                    // Use this table to temporarily store value deposited from strategy i to strategy j.
                    reallocationTable[i][j][2] += reallocationParams.priceFeedManager.assetToUsdCustomPrice(
                        assetGroup[k], depositAmount, exchangeRates[k]
                    );

                    withdrawnAssets[k] -= depositAmount; // dust-less calculation
                }
                totalUnmatchedWithdrawals -= (reallocationTable[i][j][0] - reallocationTable[j][i][0]); // dust-less calculation
            }
        }

        // Deposit assets into the underlying protocols.
        for (uint256 i; i < strategies.length; ++i) {
            IStrategy(strategies[i]).beforeDepositCheck(toDeposit[i], reallocationParams.depositSlippages[i]);

            if (toDeposit[i][assetGroup.length] == 0) {
                // There is nothing to deposit for this strategy.
                continue;
            }

            // Transfer assets from master wallet to the strategy for the deposit.
            for (uint256 j; j < assetGroup.length; ++j) {
                reallocationParams.masterWallet.transfer(IERC20(assetGroup[j]), strategies[i], toDeposit[i][j]);
            }

            // Do the deposit.
            uint256 mintedSsts = IStrategy(strategies[i]).depositFast(
                assetGroup,
                exchangeRates,
                reallocationParams.priceFeedManager,
                reallocationParams.depositSlippages[i],
                reallocationParams.swapInfo[i]
            );

            // Figure total value of assets gathered to be deposited.
            uint256 totalDepositedValue =
                reallocationParams.priceFeedManager.assetToUsdCustomPriceBulk(assetGroup, toDeposit[i], exchangeRates);

            // Distribute the minted shares to strategies that deposited into this strategy.
            for (uint256 j; j < strategies.length; ++j) {
                if (reallocationTable[j][i][2] == 0) {
                    // No shares to give to strategy j.
                    continue;
                }

                // Calculate amount of shares to give to strategy j.
                uint256 shares = mintedSsts * reallocationTable[j][i][2] / totalDepositedValue;

                mintedSsts -= shares; // dust-less calculation
                totalDepositedValue -= reallocationTable[j][i][2]; // dust-less calculation

                // Overwrite this table with amount of given shares.
                reallocationTable[j][i][2] = shares;
            }
        }
    }

    /**
     * @dev Smart vaults claim strategy shares.
     * @param smartVaults Smart vaults involved in the reallocation.
     * @param strategies Set of strategies involved in the reallocation.
     * @param strategyMapping Mapping between smart vaults' strategies and set of all strategies.
     * @param reallocationTable Filled in reallocation table.
     * @param reallocations Realllocations needed by the smart vaults.
     */
    function claimShares(
        address[] calldata smartVaults,
        address[] calldata strategies,
        uint256[][] memory strategyMapping,
        uint256[][][] memory reallocationTable,
        uint256[][][] memory reallocations
    ) private {
        // Loop over smart vaults.
        for (uint256 i; i < smartVaults.length; ++i) {
            // Number of strategies for this smart vault.
            uint256 smartVaultStrategiesLength = strategyMapping[i].length;

            // Will store amount of shares to claim from each strategy,
            // plus two temporary variables used in the calculation.
            uint256[] memory toClaim = new uint256[](smartVaultStrategiesLength+2);

            // Find strategies that needed withdrawal.
            for (uint256 j; j < smartVaultStrategiesLength; ++j) {
                if (reallocations[i][0][j] == 0) {
                    // Strategy didn't need any withdrawal.
                    continue;
                }

                // Merging two uints into an array due to stack depth.
                uint256[] memory values = new uint256[](2);
                values[0] = reallocations[i][0][j]; // value to withdraw from strategy
                values[1] = reallocations[i][1][smartVaultStrategiesLength]; // total value to deposit

                // Find strategiest that needed deposit.
                for (uint256 k; k < smartVaultStrategiesLength; ++k) {
                    if (reallocations[i][1][k] == 0) {
                        // Strategy k had no deposits planned.
                        continue;
                    }

                    // Find value that should have moved from strategy j to k.
                    uint256 valueToDeposit = values[0] * reallocations[i][1][k] / values[1];

                    // Figure out amount strategy shares to claim:
                    // - matched shares
                    toClaim[smartVaultStrategiesLength] = reallocationTable[strategyMapping[i][j]][strategyMapping[i][k]][1]
                        * valueToDeposit / reallocationTable[strategyMapping[i][j]][strategyMapping[i][k]][0];
                    // - unmatched
                    toClaim[smartVaultStrategiesLength + 1] = reallocationTable[strategyMapping[i][j]][strategyMapping[i][k]][2]
                        * valueToDeposit / reallocationTable[strategyMapping[i][j]][strategyMapping[i][k]][0];

                    reallocationTable[strategyMapping[i][j]][strategyMapping[i][k]][0] -= valueToDeposit; // dust-less calculation - reallocation level
                    reallocationTable[strategyMapping[i][j]][strategyMapping[i][k]][1] -=
                        toClaim[smartVaultStrategiesLength];
                    reallocationTable[strategyMapping[i][j]][strategyMapping[i][k]][2] -=
                        toClaim[smartVaultStrategiesLength + 1];

                    values[0] -= valueToDeposit; // dust-less calculation - smart vault level
                    values[1] -= reallocations[i][1][k];

                    // Total amount of strategy k shares to claim by this smart vault.
                    toClaim[k] += toClaim[smartVaultStrategiesLength] + toClaim[smartVaultStrategiesLength + 1];
                }
            }

            // Claim strategy shares.
            for (uint256 j; j < smartVaultStrategiesLength; ++j) {
                if (toClaim[j] == 0) {
                    // No shares to claim for strategy j.
                    continue;
                }

                IStrategy(strategies[strategyMapping[i][j]]).claimShares(smartVaults[i], toClaim[j]);
            }
        }
    }
}
