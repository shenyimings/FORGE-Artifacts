// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../dev/Deployment.sol";


contract TestDeployment is Deployment
	{
	address constant public TEAM_WALLET = address(0x123456789);


	function functionExists( address _contract, string memory _functionName ) public returns (bool)
		{
		bytes4 FUNC_SELECTOR = bytes4(keccak256( bytes(_functionName) ));

		bool success;
		bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR );

		uint256 remainingGas = gasleft();

		assembly {
			success := call(
				remainingGas,            // gas remaining
				_contract,         // destination address
				0,              // no ether
				add(data, 32),  // input buffer (starts after the first 32 bytes in the `data` array)
				mload(data),    // input length (loaded from the first 32 bytes in the `data` array)
				0,              // output buffer
				0               // output length
			)
		}

		return success;
	}


	// Tests that the contract address variables within the various contracts are correct
    function testDeployment2() public
    	{
    	// Check token decimals
		assertTrue( ERC20(address(wbtc)).decimals() == 8, "WBTC should have 8 decimals" );
		assertTrue( ERC20(address(weth)).decimals() == 18, "WETH should have 18 decimals" );
		assertTrue( ERC20(address(dai)).decimals() == 18, "DAI should have 18 decimals" );
		assertTrue( ERC20(address(salt)).decimals() == 18, "SALT should have 18 decimals" );
		assertTrue( ERC20(address(usds)).decimals() == 18, "USDS should have 18 decimals" );

        assertEq( getContract(address(exchangeConfig), "salt()"), address(salt), "Incorrect exchangeConfig.salt" );
        assertEq( getContract(address(exchangeConfig), "wbtc()"), address(wbtc), "Incorrect exchangeConfig.wbtc" );
        assertEq( getContract(address(exchangeConfig), "weth()"), address(weth), "Incorrect exchangeConfig.weth" );
        assertEq( getContract(address(exchangeConfig), "dai()"), address(dai), "Incorrect exchangeConfig.dai" );
        assertEq( getContract(address(exchangeConfig), "usds()"), address(usds), "Incorrect exchangeConfig.usds" );

        assertEq( getContract(address(exchangeConfig), "dao()"), address(dao), "Incorrect exchangeConfig.dao" );
        assertEq( getContract(address(exchangeConfig), "upkeep()"), address(upkeep), "Incorrect exchangeConfig.upkeep" );
        assertEq( getContract(address(exchangeConfig), "stakingRewardsEmitter()"), address(stakingRewardsEmitter), "Incorrect exchangeConfig.stakingRewardsEmitter" );
        assertEq( getContract(address(exchangeConfig), "liquidityRewardsEmitter()"), address(liquidityRewardsEmitter), "Incorrect exchangeConfig.liquidityRewardsEmitter" );
        assertEq( getContract(address(exchangeConfig), "accessManager()"), address(accessManager), "Incorrect exchangeConfig.accessManager" );
        assertEq( getContract(address(exchangeConfig), "initialDistribution()"), address(initialDistribution), "Incorrect exchangeConfig.initialDistribution" );
		assertEq( getContract(address(exchangeConfig), "airdrop()"), address(airdrop), "Incorrect exchangeConfig.airdrop" );

        assertEq( getContract(address(exchangeConfig), "teamWallet()"), TEAM_WALLET, "Incorrect exchangeConfig.teamWallet" );
        assertEq( getContract(address(exchangeConfig), "teamVestingWallet()"), address(teamVestingWallet), "Incorrect exchangeConfig.teamVestingWallet" );
        assertEq( getContract(address(exchangeConfig), "daoVestingWallet()"), address(daoVestingWallet), "Incorrect exchangeConfig.daoVestingWallet" );

		assertTrue( functionExists( address(teamVestingWallet), "beneficiary()" ), "For DEBUG: Incorrect exchangeConfig.teamVestingWallet" );
		assertTrue( functionExists( address(daoVestingWallet), "beneficiary()" ), "For DEBUG: Incorrect exchangeConfig.daoVestingWallet" );

        assertEq( getContract(address(airdrop), "exchangeConfig()"), address(exchangeConfig), "Incorrect airdrop.exchangeConfig" );
        assertEq( getContract(address(airdrop), "staking()"), address(staking), "Incorrect airdrop.staking" );
        assertEq( getContract(address(airdrop), "salt()"), address(salt), "Incorrect airdrop.salt" );

        assertEq( getContract(address(pools), "wbtc()"), address(wbtc), "Incorrect pools.wbtc" );
        assertEq( getContract(address(pools), "weth()"), address(weth), "Incorrect pools.weth" );
        assertEq( getContract(address(pools), "salt()"), address(salt), "Incorrect pools.salt" );
        assertEq( getContract(address(pools), "exchangeConfig()"), address(exchangeConfig), "Incorrect pools.exchangeConfig" );
        assertEq( getContract(address(pools), "poolsConfig()"), address(poolsConfig), "Incorrect pools.poolsConfig" );
        assertEq( getContract(address(pools), "usds()"), address(usds), "Incorrect pools.usds" );
        assertEq( getContract(address(pools), "dao()"), address(dao), "Incorrect pools.dao" );

        assertEq( getContract(address(staking), "exchangeConfig()"), address(exchangeConfig), "Incorrect staking.exchangeConfig" );
        assertEq( getContract(address(staking), "poolsConfig()"), address(poolsConfig), "Incorrect staking.poolsConfig" );
        assertEq( getContract(address(staking), "stakingConfig()"), address(stakingConfig), "Incorrect staking.stakingConfig" );

        assertEq( getContract(address(liquidity), "pools()"), address(pools), "Incorrect liquidity.pools" );
        assertEq( getContract(address(liquidity), "exchangeConfig()"), address(exchangeConfig), "Incorrect liquidity.exchangeConfig" );
        assertEq( getContract(address(liquidity), "poolsConfig()"), address(poolsConfig), "Incorrect liquidity.poolsConfig" );
        assertEq( getContract(address(liquidity), "stakingConfig()"), address(stakingConfig), "Incorrect liquidity.stakingConfig" );


        assertEq( getContract(address(collateral), "stableConfig()"), address(stableConfig), "Incorrect collateral.stableConfig" );
        assertEq( getContract(address(collateral), "priceAggregator()"), address(priceAggregator), "Incorrect collateral.priceAggregator" );
    	assertEq( getContract(address(collateral), "wbtc()"), address(wbtc), "Incorrect collateral.wbtc" );
        assertEq( getContract(address(collateral), "weth()"), address(weth), "Incorrect collateral.weth" );
        assertEq( getContract(address(collateral), "usds()"), address(usds), "Incorrect collateral.usds" );

        assertEq( getContract(address(collateral), "pools()"), address(pools), "Incorrect collateral.pools" );
        assertEq( getContract(address(collateral), "exchangeConfig()"), address(exchangeConfig), "Incorrect collateral.exchangeConfig" );
        assertEq( getContract(address(collateral), "poolsConfig()"), address(poolsConfig), "Incorrect collateral.poolsConfig" );
        assertEq( getContract(address(collateral), "stakingConfig()"), address(stakingConfig), "Incorrect collateral.stakingConfig" );

		assertEq( getContract(address(stakingRewardsEmitter), "stakingRewards()"), address(staking), "Incorrect stakingRewardsEmitter.stakingRewards" );
        assertEq( getContract(address(stakingRewardsEmitter), "exchangeConfig()"), address(exchangeConfig), "Incorrect stakingRewardsEmitter.exchangeConfig" );
        assertEq( getContract(address(stakingRewardsEmitter), "poolsConfig()"), address(poolsConfig), "Incorrect stakingRewardsEmitter.poolsConfig" );
		assertEq( getContract(address(stakingRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect stakingRewardsEmitter.rewardsConfig" );
		assertEq( getContract(address(stakingRewardsEmitter), "salt()"), address(salt), "Incorrect stakingRewardsEmitter.salt" );

		assertEq( getContract(address(liquidityRewardsEmitter), "stakingRewards()"), address(liquidity), "Incorrect liquidityRewardsEmitter.stakingRewards" );
		assertEq( getContract(address(liquidityRewardsEmitter), "exchangeConfig()"), address(exchangeConfig), "Incorrect liquidityRewardsEmitter.exchangeConfig" );
        assertEq( getContract(address(liquidityRewardsEmitter), "poolsConfig()"), address(poolsConfig), "Incorrect liquidityRewardsEmitter.poolsConfig" );
		assertEq( getContract(address(liquidityRewardsEmitter), "rewardsConfig()"), address(rewardsConfig), "Incorrect liquidityRewardsEmitter.rewardsConfig" );
		assertEq( getContract(address(liquidityRewardsEmitter), "salt()"), address(salt), "Incorrect liquidityRewardsEmitter.salt" );

        assertEq( getContract(address(emissions), "saltRewards()"), address(saltRewards), "Incorrect emissions.saltRewards" );
        assertEq( getContract(address(emissions), "exchangeConfig()"), address(exchangeConfig), "Incorrect emissions.exchangeConfig" );
        assertEq( getContract(address(emissions), "rewardsConfig()"), address(rewardsConfig), "Incorrect emissions.rewardsConfig" );
        assertEq( getContract(address(emissions), "salt()"), address(salt), "Incorrect emissions.salt" );

		assertEq( getContract(address(dao), "pools()"), address(pools), "Incorrect dao.pools" );
		assertEq( getContract(address(dao), "proposals()"), address(proposals), "Incorrect dao.proposals" );
        assertEq( getContract(address(dao), "exchangeConfig()"), address(exchangeConfig), "Incorrect dao.exchangeConfig" );
        assertEq( getContract(address(dao), "poolsConfig()"), address(poolsConfig), "Incorrect dao.poolsConfig" );
		assertEq( getContract(address(dao), "stakingConfig()"), address(stakingConfig), "Incorrect dao.stakingConfig" );
        assertEq( getContract(address(dao), "rewardsConfig()"), address(rewardsConfig), "Incorrect dao.rewardsConfig" );
        assertEq( getContract(address(dao), "stableConfig()"), address(stableConfig), "Incorrect dao.stableConfig" );
		assertEq( getContract(address(dao), "daoConfig()"), address(daoConfig), "Incorrect dao.daoConfig" );
		assertEq( getContract(address(dao), "priceAggregator()"), address(priceAggregator), "Incorrect dao.priceAggregator" );
        assertEq( getContract(address(dao), "liquidityRewardsEmitter()"), address(liquidityRewardsEmitter), "Incorrect dao.liquidityRewardsEmitter" );

        assertEq( getContract(address(upkeep), "pools()"), address(pools), "Incorrect upkeep.pools" );
        assertEq( getContract(address(upkeep), "exchangeConfig()"), address(exchangeConfig), "Incorrect upkeep.exchangeConfig" );
        assertEq( getContract(address(upkeep), "poolsConfig()"), address(poolsConfig), "Incorrect upkeep.poolsConfig" );
        assertEq( getContract(address(upkeep), "daoConfig()"), address(daoConfig), "Incorrect upkeep.daoConfig" );
        assertEq( getContract(address(upkeep), "priceAggregator()"), address(priceAggregator), "Incorrect upkeep.priceAggregator" );
        assertEq( getContract(address(upkeep), "saltRewards()"), address(saltRewards), "Incorrect upkeep.saltRewards" );
        assertEq( getContract(address(upkeep), "liquidity()"), address(liquidity), "Incorrect upkeep.liquidity" );
        assertEq( getContract(address(upkeep), "emissions()"), address(emissions), "Incorrect upkeep.emissions" );

        assertEq( getContract(address(upkeep), "weth()"), address(weth), "Incorrect upkeep.weth" );
        assertEq( getContract(address(upkeep), "salt()"), address(salt), "Incorrect upkeep.salt" );
        assertEq( getContract(address(upkeep), "usds()"), address(usds), "Incorrect upkeep.usds" );

		assertEq( getContract(address(proposals), "staking()"), address(staking), "Incorrect proposals.staking" );
        assertEq( getContract(address(proposals), "exchangeConfig()"), address(exchangeConfig), "Incorrect proposals.exchangeConfig" );
        assertEq( getContract(address(proposals), "poolsConfig()"), address(poolsConfig), "Incorrect proposals.poolsConfig" );
        assertEq( getContract(address(proposals), "daoConfig()"), address(daoConfig), "Incorrect proposals.daoConfig" );

		assertEq( getContract(address(saltRewards), "exchangeConfig()"), address(exchangeConfig), "Incorrect saltRewards.exchangeConfig" );
        assertEq( getContract(address(saltRewards), "rewardsConfig()"), address(rewardsConfig), "Incorrect saltRewards.rewardsConfig" );
        assertEq( getContract(address(saltRewards), "salt()"), address(salt), "Incorrect saltRewards.salt" );
        assertEq( getContract(address(saltRewards), "usds()"), address(usds), "Incorrect saltRewards.usds" );

		assertEq( getContract( address(exchangeConfig), "owner()" ), address(dao), "exchangeConfig owner is not dao" );
		assertEq( getContract( address(poolsConfig), "owner()" ), address(dao), "poolsConfig owner is not dao" );
		assertEq( getContract( address(stakingConfig), "owner()" ), address(dao), "stakingConfig owner is not dao" );
		assertEq( getContract( address(rewardsConfig), "owner()" ), address(dao), "rewardsConfig owner is not dao" );
		assertEq( getContract( address(stableConfig), "owner()" ), address(dao), "stableConfig owner is not dao" );
		assertEq( getContract( address(daoConfig), "owner()" ), address(dao), "daoConfig owner is not dao" );
		assertEq( getContract( address(priceAggregator), "owner()" ), address(dao), "priceAggregator owner is not dao" );

		assertEq( getContract(address(bootstrapBallot), "exchangeConfig()"), address(exchangeConfig), "Incorrect bootstrapBallot.exchangeConfig" );
		assertEq( getContract(address(bootstrapBallot), "airdrop()"), address(airdrop), "Incorrect bootstrapBallot.airdrop" );

		assertEq( getContract(address(initialDistribution), "salt()"), address(salt), "Incorrect initialDistribution.salt" );
		assertEq( getContract(address(initialDistribution), "poolsConfig()"), address(poolsConfig), "Incorrect initialDistribution.poolsConfig" );
		assertEq( getContract(address(initialDistribution), "emissions()"), address(emissions), "Incorrect initialDistribution.emissions" );
		assertEq( getContract(address(initialDistribution), "bootstrapBallot()"), address(bootstrapBallot), "Incorrect initialDistribution.bootstrapBallot" );
		assertEq( getContract(address(initialDistribution), "dao()"), address(dao), "Incorrect initialDistribution.dao" );
		assertEq( getContract(address(initialDistribution), "daoVestingWallet()"), address(daoVestingWallet), "Incorrect initialDistribution.daoVestingWallet" );
		assertEq( getContract(address(initialDistribution), "teamVestingWallet()"), address(teamVestingWallet), "Incorrect initialDistribution.teamVestingWallet" );
		assertEq( getContract(address(initialDistribution), "airdrop()"), address(airdrop), "Incorrect initialDistribution.airdrop" );
		assertEq( getContract(address(initialDistribution), "saltRewards()"), address(saltRewards), "Incorrect initialDistribution.saltRewards" );
		assertEq( getContract(address(initialDistribution), "liquidity()"), address(liquidity), "Incorrect initialDistribution.liquidity" );

		assertEq( salt.balanceOf(address(initialDistribution)), 100000000 ether, "The InitialDistribution contract should start with a SALT balance of 100 million SALT" );

        if ( ! DEBUG )
        	{
        	// Live on the Ethereum blockchain
        	// Check that contracts are what they are expected to be
        	assertFalse( functionExists( address(priceAggregator), "forcedPriceBTCWith18Decimals()" ), "For DEBUG: The PriceFeed should not be a ForcedPriceFeed" );

			// CoreChainlinkFeed
        	assertEq( getContract( address(priceAggregator.priceFeed1()), "CHAINLINK_BTC_USD()" ), address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c), "Incorrect BTC/USD Chainlink price feed" );
        	assertEq( getContract( address(priceAggregator.priceFeed1()), "CHAINLINK_ETH_USD()" ), address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419), "Incorrect ETH/USD Chainlink price feed" );

			// CoreUniswapFeed
        	assertEq( getContract( address(priceAggregator.priceFeed2()), "UNISWAP_V3_WBTC_WETH()" ), address(0xCBCdF9626bC03E24f779434178A73a0B4bad62eD), "Incorrect WBTC/WETH Uniswap v3 Pool" );
        	assertEq( getContract( address(priceAggregator.priceFeed2()), "UNISWAP_V3_WETH_USDC()" ), address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640), "Incorrect WETH/USDC Uniswap v3 Pool" );
			assertEq( getContract( address(priceAggregator.priceFeed2()), "wbtc()" ), address(wbtc), "Invalid priceAggregator.uniswapFeed.wbtc" );
			assertEq( getContract( address(priceAggregator.priceFeed2()), "weth()" ), address(weth), "Invalid priceAggregator.uniswapFeed.weth" );
			assertEq( getContract( address(priceAggregator.priceFeed2()), "usdc()" ), address(0x9C65b1773A95d607f41fa205511cd3327cc39D9D), "Invalid priceAggregator.uniswapFeed.usdc" );

			// CoreSaltyFeed
			assertEq( getContract( address(priceAggregator.priceFeed3()), "pools()" ), address(pools), "Invalid priceAggregator.saltyFeed.pools" );
			assertEq( getContract( address(priceAggregator.priceFeed3()), "wbtc()" ), address(wbtc), "Invalid priceAggregator.saltyFeed.wbtc" );
			assertEq( getContract( address(priceAggregator.priceFeed3()), "weth()" ), address(weth), "Invalid priceAggregator.saltyFeed.weth" );
			assertEq( getContract( address(priceAggregator.priceFeed3()), "usds()" ), address(usds), "Invalid priceAggregator.saltyFeed.usds" );

			assertEq( address(wbtc), 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, "Invalid WBTC" );
			assertEq( address(weth), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, "Invalid WETH" );
			assertEq( address(dai), 0x6B175474E89094C44Da98b954EedeAC495271d0F, "Invalid DAI" );
        	}

        assertEq( getContract(address(usds), "wbtc()"), address(wbtc), "Incorrect usds.wbtc" );
        assertEq( getContract(address(usds), "weth()"), address(weth), "Incorrect usds.weth" );
        assertEq( getContract(address(usds), "collateral()"), address(collateral), "Incorrect usds.collateral" );
        assertEq( getContract(address(usds), "pools()"), address(pools), "Incorrect usds.pools" );
        assertEq( getContract(address(usds), "exchangeConfig()"), address(exchangeConfig), "Incorrect usds.exchangeConfig" );
    	}


   	function testPrint() public view
   		{
   		console.log( "dao: ", address(dao) );
   		console.log( "emissions: ", address(emissions) );
		console.log( "" );
   		console.log( "exchangeConfig: ", address(exchangeConfig) );
   		console.log( "poolsConfig: ", address(poolsConfig) );
   		console.log( "stakingConfig: ", address(stakingConfig) );
   		console.log( "stableConfig: ", address(stableConfig) );
   		console.log( "rewardsConfig: ", address(rewardsConfig) );
   		console.log( "daoConfig: ", address(daoConfig) );
   		console.log( "priceAggregator: ", address(priceAggregator) );
		console.log( "" );
   		console.log( "salt: ", address(salt) );
   		console.log( "wbtc: ", address(wbtc) );
   		console.log( "weth: ", address(weth) );
   		console.log( "dai: ", address(dai) );
   		console.log( "usds: ", address(usds) );
		console.log( "" );
   		console.log( "stakingRewardsEmitter: ", address(stakingRewardsEmitter) );
   		console.log( "liquidityRewardsEmitter: ", address(liquidityRewardsEmitter) );
		console.log( "" );
   		console.log( "staking: ", address(staking) );
   		console.log( "liquidity: ", address(liquidity) );
   		console.log( "collateral: ", address(collateral) );
		console.log( "" );
   		console.log( "pools: ", address(pools) );
		console.log( "" );
   		console.log( "proposals: ", address(proposals) );
		console.log( "" );
   		console.log( "accessManager: ", address(accessManager) );
		console.log( "" );
   		console.log( "priceFeed1: ", address(priceAggregator.priceFeed1()) );
   		console.log( "priceFeed2: ", address(priceAggregator.priceFeed2()) );
   		console.log( "priceFeed3: ", address(priceAggregator.priceFeed3()) );
		console.log( "" );
   		console.log( "initialDistribution: ", address(initialDistribution) );
   		}
    }

