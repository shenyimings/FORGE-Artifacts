// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../Parameters.sol";
import "../../dev/Deployment.sol";
import "../DAOConfig.sol";
import "../../pools/PoolsConfig.sol";
import "../../staking/StakingConfig.sol";
import "../../rewards/RewardsConfig.sol";
import "../../stable/StableConfig.sol";
import "../../ExchangeConfig.sol";
import "./TestParameters.sol";
import "../../price_feed/PriceAggregator.sol";


contract TestParametersOffchain is Test
	{
	TestParameters public parameters;

	PoolsConfig public poolsConfig;
	StakingConfig public stakingConfig;
	RewardsConfig public rewardsConfig;
	StableConfig public stableConfig;
	ExchangeConfig public exchangeConfig;
	DAOConfig public daoConfig;
	PriceAggregator public priceAggregator;

	Deployment public deployment = new Deployment();
	address public DEPLOYER;


	constructor()
		{
		DEPLOYER = deployment.DEPLOYER();

		parameters = new TestParameters();

		vm.startPrank(address(parameters));

		poolsConfig = new PoolsConfig();
		stakingConfig = new StakingConfig();
		rewardsConfig = new RewardsConfig();
		stableConfig = new StableConfig();
		exchangeConfig = new ExchangeConfig(deployment.salt(), deployment.wbtc(), deployment.weth(), deployment.dai(), deployment.usds(), deployment.teamWallet());
		daoConfig = new DAOConfig();
		priceAggregator = new PriceAggregator();

		vm.stopPrank();
		}


	function _parameterValue( Parameters.ParameterTypes parameter ) internal view returns (uint256)
		{
		if ( parameter == Parameters.ParameterTypes.maximumWhitelistedPools )
			return poolsConfig.maximumWhitelistedPools();

		else if ( parameter == Parameters.ParameterTypes.minUnstakeWeeks )
			return stakingConfig.minUnstakeWeeks();
		else if ( parameter == Parameters.ParameterTypes.maxUnstakeWeeks )
			return stakingConfig.maxUnstakeWeeks();
		else if ( parameter == Parameters.ParameterTypes.minUnstakePercent )
			return stakingConfig.minUnstakePercent();
		else if ( parameter == Parameters.ParameterTypes.modificationCooldown )
			return stakingConfig.modificationCooldown();

		else if ( parameter == Parameters.ParameterTypes.rewardsEmitterDailyPercentTimes1000 )
			return rewardsConfig.rewardsEmitterDailyPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.emissionsWeeklyPercentTimes1000 )
			return rewardsConfig.emissionsWeeklyPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.stakingRewardsPercent )
			return rewardsConfig.stakingRewardsPercent();
		else if ( parameter == Parameters.ParameterTypes.percentRewardsSaltUSDS )
			return rewardsConfig.percentRewardsSaltUSDS();

		else if ( parameter == Parameters.ParameterTypes.rewardPercentForCallingLiquidation )
			return stableConfig.rewardPercentForCallingLiquidation();
		else if ( parameter == Parameters.ParameterTypes.maxRewardValueForCallingLiquidation )
			return stableConfig.maxRewardValueForCallingLiquidation();
		else if ( parameter == Parameters.ParameterTypes.minimumCollateralValueForBorrowing )
			return stableConfig.minimumCollateralValueForBorrowing();
		else if ( parameter == Parameters.ParameterTypes.initialCollateralRatioPercent )
			return stableConfig.initialCollateralRatioPercent();
		else if ( parameter == Parameters.ParameterTypes.minimumCollateralRatioPercent )
			return stableConfig.minimumCollateralRatioPercent();

		else if ( parameter == Parameters.ParameterTypes.bootstrappingRewards )
			return daoConfig.bootstrappingRewards();
		else if ( parameter == Parameters.ParameterTypes.percentPolRewardsBurned )
			return daoConfig.percentPolRewardsBurned();
		else if ( parameter == Parameters.ParameterTypes.baseBallotQuorumPercentTimes1000 )
			return daoConfig.baseBallotQuorumPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.ballotDuration )
			return daoConfig.ballotDuration();
		else if ( parameter == Parameters.ParameterTypes.baseProposalCost )
			return daoConfig.baseProposalCost();
		else if ( parameter == Parameters.ParameterTypes.maxPendingTokensForWhitelisting )
			return daoConfig.maxPendingTokensForWhitelisting();
		else if ( parameter == Parameters.ParameterTypes.arbitrageProfitsPercentPOL )
			return daoConfig.arbitrageProfitsPercentPOL();
		else if ( parameter == Parameters.ParameterTypes.upkeepRewardPercent )
			return daoConfig.upkeepRewardPercent();

		else if ( parameter == Parameters.ParameterTypes.maximumPriceFeedPercentDifferenceTimes1000 )
			return priceAggregator.maximumPriceFeedPercentDifferenceTimes1000();
		else if ( parameter == Parameters.ParameterTypes.setPriceFeedCooldown )
			return priceAggregator.setPriceFeedCooldown();

		require(false, "Invalid ParameterType" );
		return 0;
		}


	function _checkParameter( Parameters.ParameterTypes parameter, uint256 minValue, uint256 defaultValue, uint256 maxValue, uint256 change ) internal
		{
		assertEq( _parameterValue(parameter), defaultValue, "Default value is not as expected" );

		// Try increasing once
		parameters.executeParameterChange( parameter, true, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator );

		uint256 expectedAfterIncrease = defaultValue + change;
		if ( expectedAfterIncrease > maxValue )
			expectedAfterIncrease = maxValue;

		assertEq( _parameterValue(parameter), expectedAfterIncrease, "Increased value is not as expected" );

		// Decrease once
		parameters.executeParameterChange( parameter, false, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator );

		uint256 expectedAfterDecrease = expectedAfterIncrease - change;
		if ( expectedAfterDecrease < minValue )
			expectedAfterDecrease = minValue;

		assertEq( _parameterValue(parameter), expectedAfterDecrease, "Decreased value is not as expected" );


		// Increase until max
		while( true )
			{
			parameters.executeParameterChange( parameter, true, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator );
			if ( _parameterValue(parameter) >= maxValue )
				break;
			}

		// Increase one more time
		parameters.executeParameterChange( parameter, true, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator );
		assertEq( _parameterValue(parameter), maxValue, "Max value not as expected" );


		// Decrease until min
		while( true )
			{
			parameters.executeParameterChange( parameter, false, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator );
			if ( _parameterValue(parameter) <= minValue )
				break;
			}

		// Decrease one more time
		parameters.executeParameterChange( parameter, false, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator );
		assertEq( _parameterValue(parameter), minValue, "Min value not as expected" );
		}


	function testPoolParameters() public
		{
		vm.startPrank(address(parameters));

		_checkParameter( Parameters.ParameterTypes.maximumWhitelistedPools, 20, 50, 100, 10 );
		}


	function testStakingParameters() public
		{
		vm.startPrank(address(parameters));

		_checkParameter( Parameters.ParameterTypes.minUnstakeWeeks, 1, 2, 12, 1 );
		_checkParameter( Parameters.ParameterTypes.maxUnstakeWeeks, 20, 52, 108, 8 );
		_checkParameter( Parameters.ParameterTypes.minUnstakePercent, 10, 20, 50, 5 );
		_checkParameter( Parameters.ParameterTypes.modificationCooldown, 15 minutes, 1 hours, 6 hours, 15 minutes );
		}


	function testRewardsParameters() public
		{
		vm.startPrank(address(parameters));

		_checkParameter( Parameters.ParameterTypes.rewardsEmitterDailyPercentTimes1000, 250, 1000, 2500, 250 );
		_checkParameter( Parameters.ParameterTypes.emissionsWeeklyPercentTimes1000, 250, 500, 1000, 250 );
		_checkParameter( Parameters.ParameterTypes.stakingRewardsPercent, 25, 50, 75, 5 );
		_checkParameter( Parameters.ParameterTypes.percentRewardsSaltUSDS, 5, 10, 25, 5 );
		}


	function testStableParameters() public
		{
		vm.startPrank(address(parameters));

		// Need to increase minimumCollateralRatioPercent as minimumCollateralRatioPercent - rewardPercentForCallingLiquidation has to be greater than 105
		for( uint256 i = 0; i < 5; i++ )
			stableConfig.changeMinimumCollateralRatioPercent(true);

		_checkParameter( Parameters.ParameterTypes.rewardPercentForCallingLiquidation, 5, 5, 10, 1 );

		// Back to the default
		for( uint256 i = 0; i < 5; i++ )
			stableConfig.changeMinimumCollateralRatioPercent(false);

		_checkParameter( Parameters.ParameterTypes.maxRewardValueForCallingLiquidation, 100 ether, 500 ether, 1000 ether, 100 ether );
		_checkParameter( Parameters.ParameterTypes.minimumCollateralValueForBorrowing, 1000 ether, 2500 ether, 5000 ether, 500 ether );
		_checkParameter( Parameters.ParameterTypes.initialCollateralRatioPercent, 150, 200, 300, 25 );
		_checkParameter( Parameters.ParameterTypes.minimumCollateralRatioPercent, 110, 110, 120, 1 );
		}


	function testDAOParameters() public
		{
		vm.startPrank(address(parameters));
		_checkParameter( Parameters.ParameterTypes.bootstrappingRewards, 50000 ether, 100000 ether, 500000 ether, 50000 ether );
		_checkParameter( Parameters.ParameterTypes.percentPolRewardsBurned, 60, 75, 90, 5 );
		_checkParameter( Parameters.ParameterTypes.baseBallotQuorumPercentTimes1000, 5000, 10000, 20000, 1000 );
		_checkParameter( Parameters.ParameterTypes.ballotDuration, 3 days, 10 days, 14 days, 1 days );
		_checkParameter( Parameters.ParameterTypes.baseProposalCost, 250 ether, 500 ether, 5000 ether, 250 ether );
		_checkParameter( Parameters.ParameterTypes.maxPendingTokensForWhitelisting, 3, 5, 12, 1 );
		_checkParameter( Parameters.ParameterTypes.arbitrageProfitsPercentPOL, 15, 20, 45, 5 );
		_checkParameter( Parameters.ParameterTypes.upkeepRewardPercent, 1, 5, 10, 1 );
		}


	function testPriceAggregatorParameters() public
		{
		vm.startPrank(address(parameters));
		_checkParameter( Parameters.ParameterTypes.maximumPriceFeedPercentDifferenceTimes1000, 1000, 3000, 7000, 500 );
		_checkParameter( Parameters.ParameterTypes.setPriceFeedCooldown, 30 days, 35 days, 45 days, 5 days );
		}
    }

