// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../StableConfig.sol";

contract TestStableConfig is Test
	{
	IPriceFeed public _forcedPriceFeed = IPriceFeed(address(0xDEE776893503EFB20e6fC7173E9c03911F28233E));

	StableConfig public stableConfig;


	constructor()
		{
		stableConfig = new StableConfig();
		}


	function testRemainingRatioAfterReward() public
		{
		stableConfig.changeMinimumCollateralRatioPercent( true ); // => 111%
		stableConfig.changeRewardPercentForCallingLiquidation( true ); // ==> 6%

		uint256 startingMinimumCollateralRatioPercent = stableConfig.minimumCollateralRatioPercent();
		stableConfig.changeMinimumCollateralRatioPercent( false );
		assertEq( stableConfig.minimumCollateralRatioPercent(), startingMinimumCollateralRatioPercent, "minimumCollateralRatioPercent shouldn't change due to 105 minimum buffer with reward percent" );

		uint256 startingRewardPercentForCallingLiquidation = stableConfig.rewardPercentForCallingLiquidation();
		stableConfig.changeRewardPercentForCallingLiquidation( true );
		assertEq( stableConfig.rewardPercentForCallingLiquidation(), startingRewardPercentForCallingLiquidation, "rewardPercentForCallingLiquidation shouldn't change due to 105 minimum buffer with minimumCollateralRatioPercent" );
		}
	}
