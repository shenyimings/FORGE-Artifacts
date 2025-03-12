// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/*
 * The Stability Pool holds Debt tokens deposited by Stability Pool depositors.
 *
 * When a trove is liquidated, then depending on system conditions, some of its Debt debt gets offset with
 * Debt in the Stability Pool:  that is, the offset debt evaporates, and an equal amount of Debt tokens in the Stability Pool is burned.
 *
 * Thus, a liquidation causes each depositor to receive a Debt loss, in proportion to their deposit as a share of total deposits.
 * They also receive a collateral gain, as the collateral of the liquidated trove is distributed among Stability depositors,
 * in the same proportion.
 *
 * When a liquidation occurs, it depletes every deposit by the same fraction: for example, a liquidation that depletes 40%
 * of the total Debt in the Stability Pool, depletes 40% of each deposit.
 *
 * A deposit that has experienced a series of liquidations is termed a "compounded deposit": each liquidation depletes the deposit,
 * multiplying it by some factor in range ]0,1[
 *
 * Please see the implementation spec in the proof document, which closely follows on from the compounded deposit / collateral gain derivations:
 * https://github.com/liquity/liquity/blob/master/papers/Scalable_Reward_Distribution_with_Compounding_Stakes.pdf
 *
 * --- Prisma ISSUANCE TO STABILITY POOL DEPOSITORS ---
 *
 * An Prisma issuance event occurs at every deposit operation, and every liquidation.
 *
 * Each deposit is tagged with the address of the front end through which it was made.
 *
 * All deposits earn a share of the issued Prisma in proportion to the deposit as a share of total deposits. The Prisma earned
 * by a given deposit, is split between the depositor and the front end through which the deposit was made, based on the front end's kickbackRate.
 *
 * Please see the system Readme for an overview:
 * https://github.com/liquity/dev/blob/main/README.md#lqty-issuance-to-stability-providers
 */
interface IStabilityPool {
    // --- Functions ---

    /*
     * Initial checks:
     * - Frontend is registered or zero address
     * - Sender is not a registered frontend
     * - _amount is not zero
     * ---
     * - Triggers a Prisma issuance, based on time passed since the last issuance. The Prisma issuance is shared between *all* depositors
     * - Tags the deposit with the provided front end tag param, if it's a new deposit
     * - Accrue depositor's accumulated gains (Prisma, collateral)
     * - Increases deposit's stake, and takes a new snapshot.
     */
    function provideToSP(uint _amount) external;

    /*
     * Initial checks:
     * - _amount is zero or there are no under collateralized troves left in the system
     * - User has a non zero deposit
     * ---
     * - Triggers a Prisma issuance, based on time passed since the last issuance. The Prisma issuance is shared between *all* depositors and front ends
     * - Accrue all depositor's accumulated gains (Prisma, collateral)
     * - Decreases deposit's stake, and takes a new snapshot.
     *
     * If _amount > userDeposit, the user withdraws all of their compounded deposit.
     */
    function withdrawFromSP(uint _amount) external;

    /*
     * Initial checks:
     * - Caller is LiquidationManager
     * ---
     * Cancels out the specified debt against the Debt contained in the Stability Pool (as far as possible)
     * Only called by liquidation functions in the LiquidationManager.
     */
    function offset(address collateral, uint _debt, uint _coll) external;

    /*
     * Returns Debt held in the pool. Changes when users deposit/withdraw, and when Trove debt is offset.
     */
    function getTotalDebtTokenDeposits() external view returns (uint);

    /*
     * Calculates the collateral gain earned by the deposit since its last snapshots were taken.
     */
    function getDepositorCollateralGain(address _depositor) external view returns (uint[] memory collateralGains);

    /*
     * Calculate the Prisma gain earned by a deposit since its last snapshots were taken.
     */
    function getDepositorPrismaGain(address _depositor) external view returns (uint);

    /*
     * Return the user's compounded deposit.
     */
    function getCompoundedDebtDeposit(address _depositor) external view returns (uint);

    function enableCollateral(address collateral) external;

    function startCollateralSunset(address collateral) external;
}
