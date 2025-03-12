// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IStableConfig.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract StableConfig is IStableConfig, Ownable
    {
	// The reward (in collateraLP) that a user receives for instigating the liquidation process - as a percentage
	// of the amount of collateralLP that is liquidated.
	// Range: 5 to 10 with an adjustment of 1
    uint256 public rewardPercentForCallingLiquidation = 5;

	// The maximum reward value (in USD) that a user receives for instigating the liquidation process.
	// Range: 100 to 1000 with an adjustment of 100 ether
    uint256 public maxRewardValueForCallingLiquidation = 500 ether;

	// The minimum USD value of collateral - to borrow an initial amount of USDS.
	// This is to help prevent saturation of the contract with small amounts of positions and to ensure that
	// liquidating the position yields non-trivial rewards
	// Range: 1000 to 5000 with an adjustment of 500 ether
    uint256 public minimumCollateralValueForBorrowing = 2500 ether;

    // The ratio required for initial collateral / borrowed USDS
    // Defaults to 2.0x so that staking $1000 of BTC/ETH LP would allow you to borrow $500 of USDS
    // Range: 150 to 300 with an adjustment of 25
    uint256 public initialCollateralRatioPercent = 200;

	// The minimum ratio of collateral / borrowed USDS that can lead to the position being liquidated
	// and the user losing their collateral (and keeping the borrowed USDS)
	// Range: 110 to 120 with an adjustment of 1
	uint256 public minimumCollateralRatioPercent = 110;


	function changeRewardPercentForCallingLiquidation(bool increase) public onlyOwner
        {
        if ( ( rewardPercentForCallingLiquidation - 1 ) > minimumCollateralRatioPercent )
        	return;

		// Don't act if (minimumCollateralRatioPercent - rewardPercentForCallingLiquidation) is less than 105% to ensure that the position will be liquidatable for more than the originally borrowed USDS amount (assume reasonable market volatility)
        uint256 remainingRatioAfterReward = minimumCollateralRatioPercent - rewardPercentForCallingLiquidation - 1;

        if (increase)
            {
            if (remainingRatioAfterReward >= 105 && rewardPercentForCallingLiquidation < 10)
                rewardPercentForCallingLiquidation += 1;
            }
        else
            {
            if (rewardPercentForCallingLiquidation > 5)
                rewardPercentForCallingLiquidation -= 1;
            }
        }


	function changeMaxRewardValueForCallingLiquidation(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (maxRewardValueForCallingLiquidation < 1000 ether)
                maxRewardValueForCallingLiquidation += 100 ether;
            }
        else
            {
            if (maxRewardValueForCallingLiquidation > 100 ether)
                maxRewardValueForCallingLiquidation -= 100 ether;
            }
        }


	function changeMinimumCollateralValueForBorrowing(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (minimumCollateralValueForBorrowing < 5000 ether)
                minimumCollateralValueForBorrowing += 500 ether;
            }
        else
            {
            if (minimumCollateralValueForBorrowing > 1000 ether)
                minimumCollateralValueForBorrowing -= 500 ether;
            }
        }


	function changeInitialCollateralRatioPercent(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (initialCollateralRatioPercent < 300)
                initialCollateralRatioPercent += 25;
            }
        else
            {
            if (initialCollateralRatioPercent > 150)
                initialCollateralRatioPercent -= 25;
            }
        }


	function changeMinimumCollateralRatioPercent(bool increase) public onlyOwner
        {
        if ( rewardPercentForCallingLiquidation > minimumCollateralRatioPercent - 1 )
        	return;

        uint256 remainingRatioAfterReward = minimumCollateralRatioPercent - 1 - rewardPercentForCallingLiquidation;

        if (increase)
            {
            if (minimumCollateralRatioPercent < 120)
                minimumCollateralRatioPercent += 1;
            }
        else
            {
            if (remainingRatioAfterReward >= 105 && minimumCollateralRatioPercent > 110)
                minimumCollateralRatioPercent -= 1;
            }
        }
	}