// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../interfaces/ITokenLocker.sol";
import "../dependencies/SystemStart.sol";

/**
    @title Prisma Boost Calculator
    @notice "Boost" refers to a bonus to claimable PRISMA tokens that an account
            receives based on it's locked PRISMA weight. An account with "Max boost"
            is earning PRISMA rewards at 2x the rate of an account that is unboosted.
            Boost works as follows:

            * In a given week, the percentage of the weekly PRISMA rewards that an
            account can claim with maximum boost is the same as the percentage
            of PRISMA lock weight that the account has, relative to the total lock
            weight.
            * Once an account's weekly claims exceed the amount allowed with max boost,
            the boost rate decays linearly from 2x to 1x. This decay occurs over the same
            amount of tokens that were available for maximum boost.
            * Once an account's weekly claims are more than double the amount allowed for
            max boost, the boost bonus is fully depleted.
            * At the start of the next week, boost amounts are recalculated.

            As an example:

            * At the end of week 1, Alice has a lock weight of 100. There is a total
              lock weight of 1,000. Alice controls 10% of the total lock weight.
            * During week 2, a total of 500,000 new PRISMA rewards are made available
            * Because Alice has 10% of the lock weight in week 1, during week 2 she
              can claim up to 10% of the rewards (50,000 PRISMA) with her full boost.
            * Once Alice's weekly claim exceeds 50,000 PRISMA, her boost decays linearly
              as she claims another 50,000 PRISMA.
            * Once Alice's weekly claims exceed 100,000 PRISMA, any further claims are
              "unboosted" and receive only half as many tokens as they would have boosted.
            * At the start of the next week, Alice's boost is fully replenished. She still
              controls 10% of the total lock weight, so she can claim another 10% of this
              week's emissions at full boost.

            Note that boost is applied at the time of claiming a reward, not at the time
            the reward was earned. An account that has depleted it's boost may opt to wait
            for the start of the next week in order to claim with a larger boost.

            On a technical level, we consider the full earned reward to be the maximum
            boosted amount. "Unboosted" is more accurately described as "paying a 50%
            penalty". Rewards that go undistributed due to claims with lowered boost
            are returned to the unallocated token supply, and distributed again in the
            emissions of future weeks.
 */
contract BoostCalculator is SystemStart {
    ITokenLocker public immutable locker;

    // initial number of weeks where all accounts recieve max boost
    uint256 public immutable MAX_BOOST_GRACE_WEEKS;

    // week -> total weekly lock weight
    // tracked locally to avoid repeated external calls
    uint40[65535] totalWeeklyWeights;
    // account -> week -> % of lock weight (where 1e9 represents 100%)
    mapping(address account => uint32[65535]) accountWeeklyLockPct;

    constructor(address _prismaCore, ITokenLocker _locker, uint256 _graceWeeks) SystemStart(_prismaCore) {
        require(_graceWeeks > 0);
        locker = _locker;
        MAX_BOOST_GRACE_WEEKS = _graceWeeks;
    }

    /**
        @notice Get the adjusted claim amount after applying an account's boost
        @param account Address claiming the reward
        @param amount Amount being claimed (assuming maximum boost)
        @param previousAmount Amount that was already claimed in the current week
        @param totalWeeklyEmissions Total PRISMA emissions released this week
        @return adjustedAmount Amount of PRISMA received after applying boost
     */
    function getBoostedAmount(
        address account,
        uint256 amount,
        uint256 previousAmount,
        uint256 totalWeeklyEmissions
    ) external view returns (uint256 adjustedAmount) {
        uint256 week = getWeek();
        if (week < MAX_BOOST_GRACE_WEEKS) return amount;
        week -= 1;

        uint256 accountWeight = locker.getAccountWeightAt(account, week);
        uint256 totalWeight = locker.getTotalWeightAt(week);
        if (totalWeight == 0) totalWeight = 1;
        uint256 pct = (1e9 * accountWeight) / totalWeight;
        if (pct == 0) pct = 1;
        return _getBoostedAmount(amount, previousAmount, totalWeeklyEmissions, pct);
    }

    /**
        @notice Get the remaining claimable amounts this week that will receive boost
        @param claimant address to query boost amounts for
        @param previousAmount Amount that was already claimed in the current week
        @param totalWeeklyEmissions Total PRISMA emissions released this week
        @return maxBoosted remaining claimable amount that will receive max boost
        @return boosted remaining claimable amount that will receive some amount of boost (including max boost)
     */
    function getClaimableWithBoost(
        address claimant,
        uint256 previousAmount,
        uint256 totalWeeklyEmissions
    ) external view returns (uint256 maxBoosted, uint256 boosted) {
        uint256 week = getWeek();
        if (week < MAX_BOOST_GRACE_WEEKS) {
            uint256 remaining = totalWeeklyEmissions - previousAmount;
            return (remaining, remaining);
        }
        week -= 1;

        uint256 accountWeight = locker.getAccountWeightAt(claimant, week);
        uint256 totalWeight = locker.getTotalWeightAt(week);
        if (totalWeight == 0) totalWeight = 1;
        uint256 pct = (1e9 * accountWeight) / totalWeight;
        if (pct == 0) return (0, 0);

        uint256 maxBoostable = (totalWeeklyEmissions * pct) / 1e9;
        uint256 fullDecay = maxBoostable * 2;

        return (
            previousAmount >= maxBoostable ? 0 : maxBoostable - previousAmount,
            previousAmount >= fullDecay ? 0 : fullDecay - maxBoostable
        );
    }

    /**
        @notice Get the adjusted claim amount after applying an account's boost
        @dev Stores lock weights and percents to reduce cost on future calls
        @param account Address claiming the reward
        @param amount Amount being claimed (assuming maximum boost)
        @param previousAmount Amount that was already claimed in the current week
        @param totalWeeklyEmissions Total PRISMA emissions released this week
        @return adjustedAmount Amount of PRISMA received after applying boost
     */
    function getBoostedAmountWrite(
        address account,
        uint256 amount,
        uint256 previousAmount,
        uint256 totalWeeklyEmissions
    ) external returns (uint256 adjustedAmount) {
        uint256 week = getWeek();
        if (week < MAX_BOOST_GRACE_WEEKS) return amount;
        week -= 1;

        uint256 pct = accountWeeklyLockPct[account][week];
        if (pct == 0) {
            uint256 totalWeight = totalWeeklyWeights[week];
            if (totalWeight == 0) {
                totalWeight = locker.getTotalWeightAt(week);
                if (totalWeight == 0) totalWeight = 1;
                totalWeeklyWeights[week] = uint40(totalWeight);
            }

            uint256 accountWeight = locker.getAccountWeightAt(account, week);
            pct = (1e9 * accountWeight) / totalWeight;
            if (pct == 0) pct = 1;
            accountWeeklyLockPct[account][week] = uint32(pct);
        }

        return _getBoostedAmount(amount, previousAmount, totalWeeklyEmissions, pct);
    }

    function _getBoostedAmount(
        uint256 amount,
        uint256 previousAmount,
        uint256 totalWeeklyEmissions,
        uint256 pct
    ) internal pure returns (uint256 adjustedAmount) {
        // we use 1 to indicate no lock weight: no boost
        if (pct == 1) return amount / 2;

        uint256 total = amount + previousAmount;
        uint256 maxBoostable = (totalWeeklyEmissions * pct) / 1e9;
        uint256 fullDecay = maxBoostable * 2;

        // entire claim receives max boost
        if (maxBoostable >= total) return amount;

        // entire claim receives no boost
        if (fullDecay <= previousAmount) return amount / 2;

        // apply max boost for partial claim
        if (previousAmount < maxBoostable) {
            adjustedAmount = maxBoostable - previousAmount;
            amount -= adjustedAmount;
            previousAmount = maxBoostable;
        }

        // apply no boost for partial claim
        if (total > fullDecay) {
            adjustedAmount += (total - fullDecay) / 2;
            amount -= (total - fullDecay);
        }

        // simplified calculation if remaining claim is the entire decay amount
        if (amount == maxBoostable) return adjustedAmount + ((maxBoostable * 3) / 4);

        // remaining calculations handle claim that spans only part of the decay

        // get adjusted amount based on the final boost
        uint256 finalBoosted = amount - (amount * (previousAmount + amount - maxBoostable)) / maxBoostable / 2;
        adjustedAmount += finalBoosted;

        // get adjusted amount based on the initial boost
        uint256 initialBoosted = amount - (amount * (previousAmount - maxBoostable)) / maxBoostable / 2;
        // with linear decay, adjusted amount is half of the difference between initial and final boost amounts
        adjustedAmount += (initialBoosted - finalBoosted) / 2;

        return adjustedAmount;
    }
}
