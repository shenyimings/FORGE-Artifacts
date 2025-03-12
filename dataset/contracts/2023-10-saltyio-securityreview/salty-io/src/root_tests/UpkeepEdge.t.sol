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


contract TestUpkeepEdge is Deployment
	{
    address public constant alice = address(0x1111);


	constructor()
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

		upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);
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

//		finalizeBootstrap();
//		vm.prank(address(daoVestingWallet));
//		salt.transfer(DEPLOYER, 1000000 ether);

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		}



	// A unit test to check the behavior of performUpkeep() when the priceAggregator returns zero price
	function testPerformUpkeepZeroPrice() public
		{
		whitelistAlice();

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
		forcedPriceFeed.setBTCPrice( 0 );
		forcedPriceFeed.setETHPrice( 0 );
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
		upkeep.performUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		vm.expectRevert( "Invalid WBTC price" );
		priceAggregator.getPriceBTC();

		vm.expectRevert( "Invalid WETH price" );
		priceAggregator.getPriceETH();

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

//		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
//    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );
//
//		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
//    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


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
		upkeep.performUpkeep();
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


    // A unit test to verify the step2 function when the WBTC and WETH balance in the USDS contract are zero. Ensure that the tokens are not transferred.
    function testStep2() public
    	{
		// Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step2();

		// Check that the WBTC and WETH have been sent for counterswap
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 0 );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 0 );
    	}


    // A unit test to verify the step3 function when there is no USDS remaining to withdraw from Counterswap.
    function testStep3() public
    	{
		// Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step3();

		// Check that the Upkeep contract withdrew USDS from counterswap
		assertEq( usds.balanceOf(address(upkeep)), 0);
    	}



    // A unit test to verify the step4 function when the DAO's WETH balance is zero.
	function testStep4() public
		{
		// Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step4();

		assertEq( pools.depositedBalance(address(dao), weth), 0 ether );
		assertEq( weth.balanceOf(address(upkeep)), 0 ether );
		}


    // A unit test to verify the step5 function when the arbirtage profits for WETH are zero.
    function testStep5() public
    	{
		// Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step5(alice);

    	assertEq( weth.balanceOf(alice), 0 ether );
    	}

    // A unit test to verify the step6 function when the remainder of the WETH balance is zero.
    function testStep6() public
    	{
		// Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step6();

    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 0 ether );
    	}


    // A unit test to verify the step7 function when the remaining WETH balance in the contract is zero. Ensure that the function does not perform any actions.
	function testStep7() public
		{
		// Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step7();

		// Check that the WETH has been sent to counterswap
		assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 0 ether );
		}


    // A unit test to verify the step8 function when the deposited SALT in Counterswap is zero.
    function testStep8() public
    	{
		// Step 8. Withdraw SALT from previous counterswaps.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step8();

		// Check that the SALT has been sent to counterswap
    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );
    	}


    // A unit test to verify the step9 function when the SALT and USDS balance of the contract are zero. Ensure that the function does not perform any actions.
    function testStep9() public
    	{
		// Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
    	vm.prank(address(upkeep));
    	vm.expectRevert( "formPOL: balanceA cannot be zero" );
    	ITestUpkeep(address(upkeep)).step9();

		// Check that no SALT/USDS POL has been formed
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq(reserve0, 0 ether);
		assertEq(reserve1, 0 ether);

		(bytes32 poolID,) = PoolUtils._poolID(salt, usds);

		// liquidity should hold the actually LP in the Pools contract
    	assertEq( pools.getUserLiquidity(address(liquidity), salt, usds), 0 );

		// The DAO should have full share of the liquidity
		assertEq( liquidity.userShareForPool(address(dao), poolID), 0 );
	  	}


    // A unit test to verify the step10 function when the dao's current SALT balance is less than the starting SALT balance. Ensure that the function does not send any SALT to saltRewards.
    function testStep10LessSALT() public
    	{
    	// Mimics SALT that is already in the DAO
    	uint256 initialSaltInDAO = 1000 ether;

    	// Less SALT in the DAO than initially in the performUpkeep
    	vm.startPrank(address(initialDistribution));
    	salt.transfer(address(dao), initialSaltInDAO - 15 ether);
    	vm.stopPrank();

		// Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step10(initialSaltInDAO);

		// Nothing should have been transferred to saltRewards
		assertEq( salt.balanceOf(address(saltRewards)), 0 ether );
	  	}


    // A unit test to verify the step10 function when the dao's current SALT balance is more than the starting SALT balance. Ensure that remaining SALT is correctly calculated and sent to saltRewards.
    function testStep10MoreSALT() public
    	{
    	// Mimics SALT that is already in the DAO
    	uint256 initialSaltInDAO = 1000 ether;

    	// More SALT in the DAO than initially in the performUpkeep
    	vm.startPrank(address(initialDistribution));
    	salt.transfer(address(dao), initialSaltInDAO + 15 ether);
    	vm.stopPrank();

		// Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step10(initialSaltInDAO);

		// 15 SALT should have been transferred to saltRewards
		assertEq( salt.balanceOf(address(saltRewards)), 15 ether );
	  	}


    // A unit test to verify the step10 function when the dao's current SALT balance is equal to the starting SALT balance.
    function testStep10SameSALT() public
    	{
    	// Mimics SALT that is already in the DAO
    	uint256 initialSaltInDAO = 1000 ether;

    	// More SALT in the DAO than initially in the performUpkeep
    	vm.startPrank(address(initialDistribution));
    	salt.transfer(address(dao), initialSaltInDAO + 0 ether);
    	vm.stopPrank();

		// Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step10(initialSaltInDAO);

		// No SALT should have been transferred to saltRewards
		assertEq( salt.balanceOf(address(saltRewards)), 0 ether );
	  	}


    // A unit test to verify the step11 function when the Emissions' performUpkeep function does not emit any SALT. Ensure that it does not perform any emission actions.
	function testStep11() public
		{
		whitelistAlice();

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		assertEq( salt.balanceOf(address(emissions)), 52 * 1000000 ether );

		uint256 timeElapsed = 0;

		// Step 11. Send SALT Emissions to the SaltRewards contract.
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step11(timeElapsed);

		// Emissions initial distribution of 52 million tokens stored in the contract is a default .50% per week.
		assertEq( salt.balanceOf(address(saltRewards)), 0 );
		}


    // A unit test to verify the step12 function when the profits for pools are zero. Ensure that the function does not perform any actions.
    function testStep12() public
    	{
		bytes32[] memory poolIDs = new bytes32[](4);
		(poolIDs[0],) = PoolUtils._poolID(salt,weth);
		(poolIDs[1],) = PoolUtils._poolID(salt,wbtc);
		(poolIDs[2],) = PoolUtils._poolID(wbtc,weth);
		(poolIDs[3],) = PoolUtils._poolID(salt,usds);


		// Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step12(poolIDs);

		// Check that no rewards were sent to the SALT/USDS liquidityRewardsEmitter
		bytes32[] memory poolIDsB = new bytes32[](1);
		(poolIDsB[0],) = PoolUtils._poolID(salt, usds);
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDsB)[0], 0 );

		// Check that no rewards were sent to the stakingRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;
		assertEq( stakingRewardsEmitter.pendingRewardsForPools(poolIDsA)[0], 0 );

		// Check that no rewards were sent proportionally to the three pools involved in generating the above arbitrage
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[0], 0 );
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[1], 0 );
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[2], 0 );
	  	}


    // A unit test to verify the step13 function when there are no staking or liquidity rewards to distribute
    function testStep13() public
    	{
    	// Prepare
    	vm.prank(address(initialDistribution));
    	salt.transfer(DEPLOYER, 1000000 ether);

		bytes32[] memory poolIDs = new bytes32[](4);
		(poolIDs[0],) = PoolUtils._poolID(salt,weth);
		(poolIDs[1],) = PoolUtils._poolID(salt,wbtc);
		(poolIDs[2],) = PoolUtils._poolID(wbtc,weth);
		(poolIDs[3],) = PoolUtils._poolID(salt,usds);

		// Add some dummy initial liquidity
		vm.prank(address(collateral));
		usds.mintTo(DEPLOYER, 1000 ether);

		vm.startPrank(DEPLOYER);
		salt.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);

		liquidity.addLiquidityAndIncreaseShare( salt, weth, 1000 ether, 100 ether, 0, block.timestamp, true );
		liquidity.addLiquidityAndIncreaseShare( wbtc, salt, 10 * 10**8, 1000 ether, 0, block.timestamp, true );
		liquidity.addLiquidityAndIncreaseShare( wbtc, weth, 10 * 10**8, 100 ether, 0, block.timestamp, true );

//		salt.approve(address(pools), type(uint256).max);
//		wbtc.approve(address(pools), type(uint256).max);
//		weth.approve(address(pools), type(uint256).max);
//
//		// Place some sample trades to create arbitrage contributions for the pool stats
//		pools.depositSwapWithdraw(salt, weth, 1 ether, 0, block.timestamp);
//		pools.depositSwapWithdraw(salt, wbtc, 1 ether, 0, block.timestamp);
//		pools.depositSwapWithdraw(weth, wbtc, 1 ether, 0, block.timestamp);
//		vm.stopPrank();
//
//		// Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
//    	vm.prank(address(upkeep));
//    	ITestUpkeep(address(upkeep)).step12(poolIDs);
//
//		// Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.
//    	vm.prank(address(upkeep));
//    	ITestUpkeep(address(upkeep)).step13(1 days);
//
//		// Check if the rewards were transferred (default 1% per day...so 1% as the above timeSinceLastUpkeep is one day) to the liquidity contract
//		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);
//
//		assertEq( rewards[0], 0 );
//		assertEq( rewards[1], 0 );
//		assertEq( rewards[2], 0 );
//
//		// Check that the no staking rewards were transferred to the staking contract
//		bytes32[] memory poolIDsA = new bytes32[](1);
//		poolIDsA[0] = PoolUtils.STAKED_SALT;
//		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 0 );
	  	}


    // A unit test to verify the step14 function when the dao's POL balance is zero. Ensure that the function does not perform any actions.
    function testSuccessStep14() public
    	{
		// Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
    	vm.prank(address(upkeep));
		vm.expectRevert( "formPOL: balanceA cannot be zero" );
    	ITestUpkeep(address(upkeep)).step9();

		// DAO should have formed SALT/USDS liquidity and owns all the shares
		// Mimic reward emission
		(bytes32 poolID,) = PoolUtils._poolID(salt, usds);
		AddedReward[] memory addedRewards = new AddedReward[](1);
		addedRewards[0] = AddedReward( poolID, 100 ether );

    	vm.startPrank(address(initialDistribution));
    	salt.approve(address(liquidity), type(uint256).max);
    	liquidity.addSALTRewards(addedRewards);
    	vm.stopPrank();

		assertEq( salt.balanceOf(exchangeConfig.teamWallet()), 0);

		uint256 initialSupply = salt.totalSupply();

		// Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step14();

		// Check teamWallet transfer
		assertEq( salt.balanceOf(exchangeConfig.teamWallet()), 0 ether);

		// Check the amount burned
		uint256 amountBurned = initialSupply - salt.totalSupply();
		uint256 expectedAmountBurned = 0;
		assertEq( amountBurned, expectedAmountBurned );
	  	}


    // A unit test to verify the step15 function when the DAO vesting wallet contains no SALT. Ensure that it does not perform any release actions.
    function testSuccessStep15() public
    	{
    	assertEq( salt.balanceOf(address(daoVestingWallet)), 0 );

		// Warp to the start of when the daoVestingWallet starts to emit
		vm.warp( daoVestingWallet.start() );

		vm.warp( block.timestamp + 24 hours );
		assertEq( salt.balanceOf(address(dao)), 0 );

		// Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step15();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(address(dao)), 0 );
    	}


    // A unit test to verify the step16 function when the team's vesting wallet does not have any SALT to release. Ensure that the function does not perform any actions.
	function testSuccessStep16() public
		{
		assertEq( salt.balanceOf(address(teamVestingWallet)), 0 );

		// Warp to the start of when the teamVestingWallet starts to emit
		vm.warp( teamVestingWallet.start() );

		vm.warp( block.timestamp + 24 hours );
		assertEq( salt.balanceOf(teamWallet), 0 );

		// Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step16();

		// Check that SALT has been sent to DAO.
		assertEq( salt.balanceOf(teamWallet), 0 );
		}

	}




