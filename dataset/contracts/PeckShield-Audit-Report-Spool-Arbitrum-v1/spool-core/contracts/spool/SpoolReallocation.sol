// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

// extends
import "../interfaces/spool/ISpoolReallocation.sol";
import "./SpoolDoHardWork.sol";

// libraries
import "../libraries/Bitwise.sol";

// other imports
import "../interfaces/IVault.sol";

/**
 * @notice Spool part of implementation dealing with the reallocation of assets
 *
 * @dev
 * Allocation provider can update vault allocation across strategies.
 * This requires vault to withdraw from some and deposit to other strategies.
 * This happens across multiple vaults. The system handles all vault reallocations
 * at once and optimizes it between eachother and users.
 *
 */
abstract contract SpoolReallocation is ISpoolReallocation, SpoolDoHardWork {
    using Bitwise for uint256;

    /* ========== SET REALLOCATION ========== */

    /**
     * @notice Set vaults to reallocate on next do hard work
     * Requirements:
     * - Caller must have allocation provider role
     * - Vaults array must not be empty
     * - Vaults must be valid
     * - Strategies must be valid
     * - If reallocation was already initialized before:
     *    - Reallocation table hash must be set
     *    - Reallocation table must be valid
     *
     * @param vaults Array of vault addresses
     * @param strategies Array of strategy addresses
     * @param reallocationTable Reallocation details
     */
    function reallocateVaults(
        VaultData[] memory vaults,
        address[] memory strategies,
        uint256[][] memory reallocationTable
    ) external onlyAllocationProvider returns(uint256[][] memory) {
        require(vaults.length > 0, "NOVRLC");

        uint24 activeGlobalIndex = getActiveGlobalIndex();

        // If reallocation was already initialized before,
        // verify state and parameters before continuing
        if (reallocationIndex > 0) {
            // If reallocation was started for index and table hash is 0,
            // the reallocation was canceled. Prevent from setting it in same index again.
            require(reallocationTableHash != 0, "RLCSTP");
            // check if reallocation can still be set for same global index as before
            require(reallocationIndex == activeGlobalIndex, "RLCINP");
            // verifies strategies agains current reallocation strategies hash
            _verifyReallocationStrategies(strategies);
            _verifyReallocationTable(reallocationTable);
        } else { // if new reallocation, init empty reallocation shares table
            // verifies all system strategies using Controller contract
            _verifyStrategies(strategies);
            // hash and save strategies
            // this strategies hash is then used to verify strategies during the reallocation
            // if the strat is exploited and removed from the system, this hash is used to be consistent
            // with reallocation table ordering as system strategies change.
            _hashReallocationStrategies(strategies);
            reallocationIndex = activeGlobalIndex;
            reallocationTable = new uint256[][](strategies.length);

            for (uint256 i = 0; i < strategies.length; i++) {
                reallocationTable[i] = new uint256[](strategies.length);
            }

            emit StartReallocation(reallocationIndex);
        }

        // loop over vaults
        for (uint256 i = 0; i < vaults.length; i++) {
            // check if address is a valid vault
            _isVault(vaults[i].vault);

            // reallocate vault
            //address[] memory vaultStrategies = _buildVaultStrategiesArray(vaults[i].strategiesBitwise, vaults[i].strategiesCount, strategies);
            (uint256[] memory withdrawProportions, uint256 depositProportions) = 
                IVault(vaults[i].vault).reallocate(
                    _buildVaultStrategiesArray(vaults[i].strategiesBitwise, vaults[i].strategiesCount, strategies),
                    vaults[i].newProportions,
                    getCompletedGlobalIndex(), // NOTE: move to var if call stack not too deeep
                    activeGlobalIndex);

            // withdraw and deposit from vault strategies
            for (uint256 j = 0; j < vaults[i].strategiesCount; j++) {
                if (withdrawProportions[j] > 0) {
                    uint256 withdrawStratIndex = vaults[i].strategiesBitwise.get8BitUintByIndex(j);

                    (uint256 newSharesWithdrawn) = 
                        _reallocateVaultStratWithdraw(
                            vaults[i].vault,
                            strategies[withdrawStratIndex],
                            withdrawProportions[j],
                            activeGlobalIndex
                        );

                    _updateDepositReallocationForStrat(
                        newSharesWithdrawn,
                        vaults[i],
                        depositProportions,
                        reallocationTable[withdrawStratIndex]
                    );
                }
            }
        }        

        // Hash reallocation proportions
        _hashReallocationTable(reallocationTable);

        return reallocationTable;
    }

    /**
     * @notice Remove shares from strategy to set them for a reallocation
     * @param vaultAddress Vault address
     * @param strat Strategy address to remove shares
     * @param vaultProportion Proportion of all vault-strategy shares a vault wants to reallocate
     * @param index Global index we're reallocating for
     * @return newSharesWithdrawn New shares withdrawn fro reallocation
     */
    function _reallocateVaultStratWithdraw(
        address vaultAddress,
        address strat, 
        uint256 vaultProportion,
        uint256 index
    )
        private returns (uint128 newSharesWithdrawn)
    {
        Strategy storage strategy = strategies[strat];
        Vault storage vault = strategy.vaults[vaultAddress];
        VaultBatch storage vaultBatch = vault.vaultBatches[index];

        // calculate new shares to withdraw
        uint128 unwithdrawnVaultShares = vault.shares - vaultBatch.withdrawnShares;

        // if strategy wasn't executed in current batch yet, also substract unprocessed withdrawal shares in current batch

        if(!_isNextStrategyIndex(strategy, index)) {
            VaultBatch storage vaultBatchPrevious = vault.vaultBatches[index - 1];
            unwithdrawnVaultShares -= vaultBatchPrevious.withdrawnShares;
        }

        // return data
        newSharesWithdrawn = Math.getProportion128(unwithdrawnVaultShares, vaultProportion, ACCURACY);

        // save to storage
        vault.withdrawnReallocationShares = newSharesWithdrawn;
    }

    /**
     * @notice Checks whether the given index is next index for the strategy
     * @param strategy Strategy data (see Strategy struct)
     * @param interactingIndex Index to check
     * @return isNextStrategyIndex True if given index is the next strategy index
     */
    function _isNextStrategyIndex(
        Strategy storage strategy,
        uint256 interactingIndex
    ) internal view returns (bool isNextStrategyIndex) {
        if (strategy.index + 1 == interactingIndex) {
            isNextStrategyIndex = true;
        }
    }

    /**
     * @notice Update deposit reallocation for strategy
     * @param sharesWithdrawn Withdrawn shares
     * @param vaultData Vault data (see VaultData struct)
     * @param depositProportions Deposit proportions
     * @param stratReallocationTable Strategy reallocation table
     */
    function _updateDepositReallocationForStrat(
        uint256 sharesWithdrawn,
        VaultData memory vaultData,
        uint256 depositProportions,
        uint256[] memory stratReallocationTable
    ) private pure {
        // sharesToDeposit = sharesWithdrawn * deposit_strat%
        uint256 sharesWithdrawnleft = sharesWithdrawn;
        uint256 lastDepositedIndex = 0;
        for (uint256 i = 0; i < vaultData.strategiesCount; i++) {

            uint256 stratDepositProportion = depositProportions.get14BitUintByIndex(i);
            if (stratDepositProportion > 0) {
                uint256 globalStratIndex = vaultData.strategiesBitwise.get8BitUintByIndex(i);
                uint256 withdrawnSharesForStrat = Math.getProportion128(sharesWithdrawn, stratDepositProportion, FULL_PERCENT);
                stratReallocationTable[globalStratIndex] += withdrawnSharesForStrat;
                sharesWithdrawnleft -= withdrawnSharesForStrat;
                lastDepositedIndex = globalStratIndex;
            }
        }

        // add shares left from rounding error to last deposit strat
        stratReallocationTable[lastDepositedIndex] += sharesWithdrawnleft;
    }

    /* ========== SHARED ========== */

    /**
     * @notice Build vault strategies array from a 256bit word.
     * @dev Each vault index takes 8bits.
     *
     * @param bitwiseAddressIndexes Bitwise address indexes
     * @param strategiesCount Strategies count
     * @param strategies Array of strategy addresses
     * @return vaultStrategies Array of vault strategy addresses
     */
    function _buildVaultStrategiesArray(
        uint256 bitwiseAddressIndexes,
        uint256 strategiesCount,
        address[] memory strategies
    ) private pure returns(address[] memory vaultStrategies) {
        vaultStrategies = new address[](strategiesCount);

        for (uint256 i = 0; i < strategiesCount; i++) {
            uint256 stratIndex = bitwiseAddressIndexes.get8BitUintByIndex(i);
            vaultStrategies[i] = strategies[stratIndex];
        }
    }
}