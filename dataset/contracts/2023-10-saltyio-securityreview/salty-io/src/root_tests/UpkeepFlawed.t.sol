// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";
import "../root_tests/TestERC20.sol";
import "../pools/PoolUtils.sol";
import "../Upkeep.sol";
import "../pools/PoolsConfig.sol";
import "../price_feed/PriceAggregator.sol";
import "../ExchangeConfig.sol";
import "../staking/Liquidity.sol";
import "../stable/Collateral.sol";
import "../pools/Pools.sol";
import "../staking/Staking.sol";
import "../rewards/RewardsEmitter.sol";
import "../dao/Proposals.sol";
import "../dao/DAO.sol";
import "../AccessManager.sol";
import "../launch/InitialDistribution.sol";
import "../dao/DAOConfig.sol";
import "./ITestUpkeep.sol";
import "./UpkeepFlawed.sol";
import "./IUpkeepFlawed.sol";
import "../launch/tests/TestBootstrapBallot.sol";


contract TestUpkeepFlawed is Deployment
	{
    address public constant alice = address(0x1111);


	function _initFlawed( uint256 stepToRevert ) internal
		{
		// Transfer the salt from the original initialDistribution to the DEPLOYER
		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);

		vm.startPrank(DEPLOYER);

		poolsConfig = new PoolsConfig();
		usds = new USDS(wbtc, weth);

		exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet );

		priceAggregator = new PriceAggregator();
		priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
		collateral = new Collateral(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator);

		stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig );
		liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig );

		saltRewards = new SaltRewards(exchangeConfig, rewardsConfig);
		emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

		poolsConfig.whitelistPool(pools, salt, wbtc);
		poolsConfig.whitelistPool(pools, salt, weth);
		poolsConfig.whitelistPool(pools, salt, usds);
		poolsConfig.whitelistPool(pools, wbtc, usds);
		poolsConfig.whitelistPool(pools, weth, usds);
		poolsConfig.whitelistPool(pools, wbtc, dai);
		poolsConfig.whitelistPool(pools, weth, dai);
		poolsConfig.whitelistPool(pools, usds, dai);
		poolsConfig.whitelistPool(pools, wbtc, weth);

		proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

		address oldDAO = address(dao);
		dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter);

		airdrop = new Airdrop(exchangeConfig, staking);

		accessManager = new AccessManager(dao);

		exchangeConfig.setAccessManager( accessManager );
		exchangeConfig.setStakingRewardsEmitter( stakingRewardsEmitter);
		exchangeConfig.setLiquidityRewardsEmitter( liquidityRewardsEmitter);
		exchangeConfig.setDAO( dao );
		exchangeConfig.setAirdrop(airdrop);

		upkeep = new UpkeepFlawed(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions, stepToRevert);
		exchangeConfig.setUpkeep(upkeep);

		daoVestingWallet = new VestingWallet( address(dao), uint64(block.timestamp + 60 * 60 * 24 * 7), 60 * 60 * 24 * 365 * 10 );
		teamVestingWallet = new VestingWallet( address(upkeep), uint64(block.timestamp + 60 * 60 * 24 * 7), 60 * 60 * 24 * 365 * 10 );
		exchangeConfig.setVestingWallets(address(teamVestingWallet), address(daoVestingWallet));

		bootstrapBallot = new TestBootstrapBallot(exchangeConfig, airdrop, 60 * 60 * 24 * 3 );
		initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);
		exchangeConfig.setInitialDistribution(initialDistribution);

		pools.setDAO(dao);


		usds.setContracts(collateral, pools, exchangeConfig );

		// Transfer ownership of the newly created config files to the DAO
		Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
		Ownable(address(poolsConfig)).transferOwnership( address(dao) );
		Ownable(address(priceAggregator)).transferOwnership(address(dao));
		vm.stopPrank();

		vm.startPrank(address(oldDAO));
		Ownable(address(stakingConfig)).transferOwnership( address(dao) );
		Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
		Ownable(address(stableConfig)).transferOwnership( address(dao) );
		Ownable(address(daoConfig)).transferOwnership( address(dao) );
		vm.stopPrank();

		// Move the SALT to the new initialDistribution contract
		vm.prank(DEPLOYER);
		salt.transfer(address(initialDistribution), 100000000 ether);

		whitelistAlice();
		}


	// A unit test to revert step1 and ensure other steps continue functioning
	function testRevertStep1() public
		{
		_initFlawed(1);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
//		assertEq( priceAggregator.getPriceBTC(), 20000 ether );
//		assertEq( priceAggregator.getPriceETH(), 2000 ether );
		assertEq( priceAggregator.getPriceBTC(), 10000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 1000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 40 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 31000000000000000000, "step 9 A" );
		assertEq( reserve1, 31000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}


	// A unit test to revert step2 and ensure other steps continue functioning
	function testRevertStep2() public
		{
		_initFlawed(2);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether );
		assertEq( priceAggregator.getPriceETH(), 2000 ether );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
//		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
//		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 0 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 9500000000000000000, "step2 B" );

		// Check that USDS has been burned
//		assertEq( usds.totalSupply(), 40 ether, "step2 C" );
		assertEq( usds.totalSupply(), 60 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 9500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 31000000000000000000, "step 9 A" );
		assertEq( reserve1, 31000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}


	// A unit test to revert step3 and ensure other steps continue functioning
	function testRevertStep3() public
		{
		_initFlawed(3);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 40 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
//		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );
		assertEq( usds.balanceOf(address(upkeep)), 0 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
//    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );
    	assertEq( salt.balanceOf(address(upkeep)), 1000000000000000000, "step 8 A" ); // No POL was formed so the SALT wasn't used

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
//		assertEq( reserve0, 31000000000000000000, "step 9 A" );
//		assertEq( reserve1, 31000000000000000000, "step 9 B" );
		assertEq( reserve0, 1000000000000000000, "step 9 A" );
		assertEq( reserve1, 1000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();
//   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
   		assertEq( saltBurned, 0, "step 14 A" ); // no POL means no SALT burned
		}




	// A unit test to revert step4 and ensure other steps continue functioning
	function testRevertStep4() public
		{
		_initFlawed(4);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
//		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 50000000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 40 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
//    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );
    	assertEq( pools.depositedBalance(address(dao), weth), 100 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
//    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );
    	assertEq( weth.balanceOf(upkeepCaller), 0, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
//    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 50000000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
//    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 0, "step7 A" );

		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 31000000000000000000, "step 9 A" );
		assertEq( reserve1, 31000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}




	// A unit test to revert step5 and ensure other steps continue functioning
	function testRevertStep5() public
		{
		_initFlawed(5);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
//		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 60000000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 40 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
//    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );
    	assertEq( weth.balanceOf(upkeepCaller), 0, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
//    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 60000000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 90000000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 31000000000000000000, "step 9 A" );
		assertEq( reserve1, 31000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}



	// A unit test to revert step6 and ensure other steps continue functioning
	function testRevertStep6() public
		{
		_initFlawed(6);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
//		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 50000000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 40 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
//    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 50000000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
//    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 95000000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 31000000000000000000, "step 9 A" );
		assertEq( reserve1, 31000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}




	// A unit test to revert step7 and ensure other steps continue functioning
	function testRevertStep7() public
		{
		_initFlawed(7);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 40 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
//    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 0, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 31000000000000000000, "step 9 A" );
		assertEq( reserve1, 31000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}




	// A unit test to revert step8 and ensure other steps continue functioning
	function testRevertStep8() public
		{
		_initFlawed(8);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 40 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
		// Reverting this doesn't affect POL formation as USDS is the limiting factor in creating the POL
		// Balance still zero after step8 reversion
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 31000000000000000000, "step 9 A" );
		assertEq( reserve1, 31000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}




	// A unit test to revert step9 and ensure other steps continue functioning
	function testRevertStep9() public
		{
		_initFlawed(9);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 40 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
//    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );
    	assertEq( salt.balanceOf(address(upkeep)), 1000000000000000000, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
//		assertEq( reserve0, 31000000000000000000, "step 9 A" );
//		assertEq( reserve1, 31000000000000000000, "step 9 B" );
		assertEq( reserve0, 1000000000000000000, "step 9 A" );
		assertEq( reserve1, 1000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

//   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
   		assertEq( saltBurned, 0, "step 14 A" );
		}



	// A unit test to revert step10 and ensure other steps continue functioning
	function testRevertStep10() public
		{
		_initFlawed(10);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 300 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 150 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 150 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 310 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 300 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 16 A" );


//		console.log( "TEAM SALT: ", salt.balanceOf(teamWallet) );

		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		// More is sent than usual so that some will exist to send to saltRewards after forming POL
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 500 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 500 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 301000000000000000000, "step 9 A" );
		assertEq( reserve1, 301000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
//		assertEq( salt.balanceOf(address(saltRewards)), 163436428571428571428571, "step 10 A" );
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}


	// A unit test to revert step11 and ensure other steps continue functioning
	function testRevertStep11() public
		{
		_initFlawed(11);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 300 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 150 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 150 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 310 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 300 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
//		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
//		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 2970000000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 30000000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 16 A" );


//		console.log( "TEAM SALT: ", salt.balanceOf(teamWallet) );

		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		// More is sent than usual so that some will exist to send to saltRewards after forming POL
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 500 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 500 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 301000000000000000000, "step 9 A" );
		assertEq( reserve1, 301000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
//		assertEq( salt.balanceOf(address(saltRewards)), 163436428571428571428571, "step 10 A" );
		assertEq( salt.balanceOf(address(saltRewards)), 110000000000000000000, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}


	// A unit test to revert step12 and ensure other steps continue functioning
	function testRevertStep12() public
		{
		_initFlawed(12);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


		// Dummy WBTC and WETH to send to USDS
		vm.startPrank(DEPLOYER);
		wbtc.transfer( address(usds), 5 ether );
		weth.transfer( address(usds), 50 ether );
		vm.stopPrank();

		// USDS to usds contract to mimic withdrawn counterswap trades
		vm.startPrank( address(collateral));
		usds.mintTo( address(usds), 30 ether );
		usds.shouldBurnMoreUSDS( 20 ether );
		vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


		// USDS deposited to counterswap to mimic completed counterswap trades
		vm.prank( address(collateral));
		usds.mintTo( address(usds), 300 ether );

		vm.startPrank(address(usds));
		usds.approve( address(pools), type(uint256).max );
		pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 150 ether);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 150 ether);
		vm.stopPrank();


		// Arbitrage profits are deposited as WETH for the DAO
		vm.prank(DEPLOYER);
		weth.transfer(address(dao), 100 ether);

		vm.startPrank(address(dao));
		weth.approve(address(pools), 100 ether);
		pools.deposit(weth, 100 ether);
		vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 310 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 300 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
		assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
		assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
		assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
		assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
//		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
//		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 2970000000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 30000000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
		assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
		assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 16 A" );


//		console.log( "TEAM SALT: ", salt.balanceOf(teamWallet) );

		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		// More is sent than usual so that some will exist to send to saltRewards after forming POL
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 500 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 500 ether);
		vm.stopPrank();

		assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
		assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 301000000000000000000, "step 9 A" );
		assertEq( reserve1, 301000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
//		assertEq( salt.balanceOf(address(saltRewards)), 163436428571428571428571, "step 10 A" );
		assertEq( salt.balanceOf(address(saltRewards)), 297157142857142857142857, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}


		// A unit test to revert step13 and ensure other steps continue functioning
    	function testRevertStep13() public
    		{
    		_initFlawed(13);

    		vm.prank(address(bootstrapBallot));
    		initialDistribution.distributionApproved();

    		// Set an initial price
    		vm.startPrank(DEPLOYER);
    		forcedPriceFeed.setBTCPrice( 10000 ether );
    		forcedPriceFeed.setETHPrice( 1000 ether );
    		vm.stopPrank();

    		priceAggregator.performUpkeep();

    		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
    		assertEq( priceAggregator.getPriceETH(), 1000 ether );

    		// Set a new price
    		vm.startPrank(DEPLOYER);
    		forcedPriceFeed.setBTCPrice( 20000 ether );
    		forcedPriceFeed.setETHPrice( 2000 ether );
    		vm.stopPrank();


        	// Dummy WBTC and WETH to send to USDS
        	vm.startPrank(DEPLOYER);
        	wbtc.transfer( address(usds), 5 ether );
        	weth.transfer( address(usds), 50 ether );
        	vm.stopPrank();

        	// USDS to usds contract to mimic withdrawn counterswap trades
        	vm.startPrank( address(collateral));
        	usds.mintTo( address(usds), 30 ether );
        	usds.shouldBurnMoreUSDS( 20 ether );
        	vm.stopPrank();

    		assertEq( usds.totalSupply(), 30 ether );


        	// USDS deposited to counterswap to mimic completed counterswap trades
        	vm.prank( address(collateral));
        	usds.mintTo( address(usds), 300 ether );

        	vm.startPrank(address(usds));
        	usds.approve( address(pools), type(uint256).max );
        	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 150 ether);
        	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 150 ether);
    		vm.stopPrank();


        	// Arbitrage profits are deposited as WETH for the DAO
        	vm.prank(DEPLOYER);
        	weth.transfer(address(dao), 100 ether);

        	vm.startPrank(address(dao));
        	weth.approve(address(pools), 100 ether);
        	pools.deposit(weth, 100 ether);
        	vm.stopPrank();

    		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
    		vm.startPrank(DEPLOYER);
    		wbtc.approve(address(pools), type(uint256).max);
    		weth.approve(address(pools), type(uint256).max);
    		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
    		vm.stopPrank();

    		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
    		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

    		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    		assertEq( salt.balanceOf(address(staking)), 0 );


    		// === Perform upkeep ===
    		address upkeepCaller = address(0x9999);

    		vm.prank(upkeepCaller);
    		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    		// ==================


    		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
    		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
    		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

    		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
    		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
    		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

    		// Check that USDS has been burned
    		assertEq( usds.totalSupply(), 310 ether, "step2 C" );

    		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
    		assertEq( usds.balanceOf(address(upkeep)), 300 ether, "step3 A" );

    		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
        	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

    		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
        	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

    		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
    		// Includes deposited WETH from step2 as well
        	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

    		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
        	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


    		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

    		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
    		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
    		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
//    		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
//    		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );
    		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3117000000000000000000005, "step11-13 A" );
    		assertEq( salt.balanceOf(address(staking)), 0, "step11-13 B" );

    		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
//    		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );
    		assertEq( salt.balanceOf(address(liquidity)), 0, "step11-13 C" );

    		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

    		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
        	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 15 A" );

    		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
        	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 16 A" );


    //		console.log( "TEAM SALT: ", salt.balanceOf(teamWallet) );

    		// Have the team form some initial SALT/USDS liquidity
    		vm.prank(address(collateral));
    		usds.mintTo(teamWallet, 1 ether);

    		vm.startPrank(teamWallet);
    		salt.approve(address(pools), 1 ether);
    		usds.approve(address(pools), 1 ether);
    		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
    		vm.stopPrank();

    		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
    		// More is sent than usual so that some will exist to send to saltRewards after forming POL
    		vm.prank(teamWallet);
    		salt.transfer(address(upkeep), 500 ether);

    		vm.startPrank(address(upkeep));
    		salt.approve(address(pools), type(uint256).max);
    		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 500 ether);
    		vm.stopPrank();

        	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

    		uint256 saltSupply = salt.totalSupply();

    		// =====Perform another performUpkeep
    		vm.warp(block.timestamp + 1 days);

    		vm.prank(upkeepCaller);
    		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    		// =====


    		// Check Step 8. Withdraw SALT from previous counterswaps.
    		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
        	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

    		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
    		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
    		assertEq( reserve0, 301000000000000000000, "step 9 A" );
    		assertEq( reserve1, 301000000000000000000, "step 9 B" );

    		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
    		assertEq( salt.balanceOf(address(saltRewards)), 163436428571428571428571, "step 10 A" );

    		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
    		uint256 saltBurned = saltSupply - salt.totalSupply();

//       		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
       		assertEq( saltBurned, 0, "step 14 A" );
    		}


	// A unit test to revert step14 and ensure other steps continue functioning
	function testRevertStep14() public
		{
		_initFlawed(14);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 300 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 150 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 150 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 310 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 300 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 16 A" );


//		console.log( "TEAM SALT: ", salt.balanceOf(teamWallet) );

		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		// More is sent than usual so that some will exist to send to saltRewards after forming POL
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 500 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 500 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 301000000000000000000, "step 9 A" );
		assertEq( reserve1, 301000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163436428571428571428571, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

//   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
   		assertEq( saltBurned, 0, "step 14 A" );
		}


		// A unit test to revert step15 and ensure other steps continue functioning
    	function testRevertStep15() public
    		{
    		_initFlawed(15);

    		vm.prank(address(bootstrapBallot));
    		initialDistribution.distributionApproved();

    		// Set an initial price
    		vm.startPrank(DEPLOYER);
    		forcedPriceFeed.setBTCPrice( 10000 ether );
    		forcedPriceFeed.setETHPrice( 1000 ether );
    		vm.stopPrank();

    		priceAggregator.performUpkeep();

    		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
    		assertEq( priceAggregator.getPriceETH(), 1000 ether );

    		// Set a new price
    		vm.startPrank(DEPLOYER);
    		forcedPriceFeed.setBTCPrice( 20000 ether );
    		forcedPriceFeed.setETHPrice( 2000 ether );
    		vm.stopPrank();


        	// Dummy WBTC and WETH to send to USDS
        	vm.startPrank(DEPLOYER);
        	wbtc.transfer( address(usds), 5 ether );
        	weth.transfer( address(usds), 50 ether );
        	vm.stopPrank();

        	// USDS to usds contract to mimic withdrawn counterswap trades
        	vm.startPrank( address(collateral));
        	usds.mintTo( address(usds), 30 ether );
        	usds.shouldBurnMoreUSDS( 20 ether );
        	vm.stopPrank();

    		assertEq( usds.totalSupply(), 30 ether );


        	// USDS deposited to counterswap to mimic completed counterswap trades
        	vm.prank( address(collateral));
        	usds.mintTo( address(usds), 300 ether );

        	vm.startPrank(address(usds));
        	usds.approve( address(pools), type(uint256).max );
        	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 150 ether);
        	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 150 ether);
    		vm.stopPrank();


        	// Arbitrage profits are deposited as WETH for the DAO
        	vm.prank(DEPLOYER);
        	weth.transfer(address(dao), 100 ether);

        	vm.startPrank(address(dao));
        	weth.approve(address(pools), 100 ether);
        	pools.deposit(weth, 100 ether);
        	vm.stopPrank();

    		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
    		vm.startPrank(DEPLOYER);
    		wbtc.approve(address(pools), type(uint256).max);
    		weth.approve(address(pools), type(uint256).max);
    		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
    		vm.stopPrank();

    		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
    		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

    		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    		assertEq( salt.balanceOf(address(staking)), 0 );


    		// === Perform upkeep ===
    		address upkeepCaller = address(0x9999);

    		vm.prank(upkeepCaller);
    		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    		// ==================


    		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
    		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
    		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

    		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
    		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
    		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

    		// Check that USDS has been burned
    		assertEq( usds.totalSupply(), 310 ether, "step2 C" );

    		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
    		assertEq( usds.balanceOf(address(upkeep)), 300 ether, "step3 A" );

    		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
        	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

    		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
        	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

    		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
    		// Includes deposited WETH from step2 as well
        	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

    		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
        	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


    		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

    		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
    		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
    		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
    		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
    		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

    		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
    		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

    		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

    		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
//        	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 15 A" );
        	assertEq( salt.balanceOf(address(dao)), 0, "step 15 A" );

    		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
        	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 16 A" );


    //		console.log( "TEAM SALT: ", salt.balanceOf(teamWallet) );

    		// Have the team form some initial SALT/USDS liquidity
    		vm.prank(address(collateral));
    		usds.mintTo(teamWallet, 1 ether);

    		vm.startPrank(teamWallet);
    		salt.approve(address(pools), 1 ether);
    		usds.approve(address(pools), 1 ether);
    		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
    		vm.stopPrank();

    		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
    		// More is sent than usual so that some will exist to send to saltRewards after forming POL
    		vm.prank(teamWallet);
    		salt.transfer(address(upkeep), 500 ether);

    		vm.startPrank(address(upkeep));
    		salt.approve(address(pools), type(uint256).max);
    		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 500 ether);
    		vm.stopPrank();

        	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

    		uint256 saltSupply = salt.totalSupply();

    		// =====Perform another performUpkeep
    		vm.warp(block.timestamp + 1 days);

    		vm.prank(upkeepCaller);
    		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    		// =====


    		// Check Step 8. Withdraw SALT from previous counterswaps.
    		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
        	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

    		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
    		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
    		assertEq( reserve0, 301000000000000000000, "step 9 A" );
    		assertEq( reserve1, 301000000000000000000, "step 9 B" );

    		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
    		assertEq( salt.balanceOf(address(saltRewards)), 163436428571428571428571, "step 10 A" );

    		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
    		uint256 saltBurned = saltSupply - salt.totalSupply();

       		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
    		}


	// A unit test to revert step16 and ensure other steps continue functioning
	function testRevertStep16() public
		{
		_initFlawed(16);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 20000 ether );
		forcedPriceFeed.setETHPrice( 2000 ether );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 300 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 150 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 150 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		IUpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether, "step1 A" );
		assertEq( priceAggregator.getPriceETH(), 2000 ether, "step1 B" );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 310 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 300 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 15 A" );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
//    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 1 days / (60 * 60 * 24 * 365 * 10), "step 16 A" );
    	assertEq( salt.balanceOf(address(teamWallet)), 0, "step 16 A" );
		}

	}
