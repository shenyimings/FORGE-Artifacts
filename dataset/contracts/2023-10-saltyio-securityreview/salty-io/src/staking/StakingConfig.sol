// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IStakingConfig.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract StakingConfig is IStakingConfig, Ownable
    {
	// The minimum number of weeks for an unstake request at which point minUnstakePercent of the original staked SALT is reclaimable.
	// Range: 1 to 12 with an adjustment of 1
	uint256 public minUnstakeWeeks = 2;  // minUnstakePercent returned for unstaking this number of weeks

	// The maximum number of weeks for an unstake request at which point 100% of the original staked SALT is reclaimable.
	// Range: 20 to 108 with an adjustment of 8
	uint256 public maxUnstakeWeeks = 52;

	// The percentage of the original staked SALT that is reclaimable when unstaking the minimum number of weeks.
	// Range: 10 to 50 with an adjustment of 5
	uint256 public minUnstakePercent = 20;

	// Minimum time between increasing and decreasing user share in SharedRewards contracts.
	// Prevents reward hunting where users could frontrun reward distributions and then immediately withdraw.
	// Range: 15 minutes to 6 hours with an adjustment of 15 minutes
	uint256 public modificationCooldown = 1 hours;


	function changeMinUnstakeWeeks(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (minUnstakeWeeks < 12)
                minUnstakeWeeks += 1;
            }
        else
            {
            if (minUnstakeWeeks > 1)
                minUnstakeWeeks -= 1;
            }
        }


	function changeMaxUnstakeWeeks(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (maxUnstakeWeeks < 108)
                maxUnstakeWeeks += 8;
            }
        else
            {
            if (maxUnstakeWeeks > 20)
                maxUnstakeWeeks -= 8;
            }
        }


	function changeMinUnstakePercent(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (minUnstakePercent < 50)
                minUnstakePercent += 5;
            }
        else
            {
            if (minUnstakePercent > 10)
                minUnstakePercent -= 5;
            }
        }


	function changeModificationCooldown(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (modificationCooldown < 6 hours)
                modificationCooldown += 15 minutes;
            }
        else
            {
            if (modificationCooldown > 15 minutes)
                modificationCooldown -= 15 minutes;
            }
        }
    }