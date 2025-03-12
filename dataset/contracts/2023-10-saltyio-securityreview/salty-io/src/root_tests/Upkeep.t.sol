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
import "../launch/tests/TestBootstrapBallot.sol";


contract TestUpkeep2 is Deployment
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


   	// A unit test to check the constructor when supplied parameters contain a zero address. Ensure that the constructor reverts with the correct error message.
	function test_construct_with_zero_addresses_fails() public {

		IPools _pools = IPools(address(0));
		IExchangeConfig _exchangeConfig = IExchangeConfig(address(0));
		IPoolsConfig _poolsConfig = IPoolsConfig(address(0));
		IDAOConfig _daoConfig = IDAOConfig(address(0));
		IPriceAggregator _priceAggregator = IPriceAggregator(address(0));
		ISaltRewards _saltRewards = ISaltRewards(address(0));
		ILiquidity _liquidity = ILiquidity(address(0));
		IEmissions _emissions = IEmissions(address(0));

		vm.expectRevert("_pools cannot be address(0)");
		new Upkeep(_pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_exchangeConfig cannot be address(0)");
		new Upkeep(pools, _exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_poolsConfig cannot be address(0)");
		new Upkeep(pools, exchangeConfig, _poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_daoConfig cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, _daoConfig, priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_priceAggregator cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, _priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_saltRewards cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, _saltRewards, liquidity, emissions);

		vm.expectRevert("_liquidity cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, _liquidity, emissions);

		vm.expectRevert("_emissions cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, _emissions);
	}


    // A unit test to check the performUpkeep function and ensure that lastUpkeepTime state variable is updated.
    function testPerformUpkeep() public
    {
        // Arrange
        vm.prank(DEPLOYER);
        uint256 daoStartingSaltBalance = salt.balanceOf( address(exchangeConfig.dao()) );
        uint256 blockTimeStampBefore = block.timestamp;

        vm.warp( blockTimeStampBefore + 90 ); // Advance the timestamp by 90 seconds

        // Act
        upkeep.performUpkeep();

        // Assert
        uint256 updatedLastUpkeepTime = upkeep.lastUpkeepTime();
        assertEq(updatedLastUpkeepTime, blockTimeStampBefore + 90, "lastUpkeepTime is not updated");

        assertEq(daoStartingSaltBalance, salt.balanceOf( address(exchangeConfig.dao()) ), "Salt balance of dao is not the same");
    }


    // A unit test to verify the onlySameContract modifier. Test by calling a function with the modifier from another contract and ensure it reverts with the correct error message.
	function testUpkeepModifier() public {
        vm.expectRevert("Only callable from within the same contract");
        ITestUpkeep(address(upkeep)).step1();
    }


    // A unit test to verify the performUpkeep function when it is called multiple times in quick succession. Ensure that the lastUpkeepTime is correctly updated on each call.
    function testUpdateLastUpkeepTime() public {

            for (uint i=0; i < 5; i++)
            	{
            	uint256 timeIncrease = i * 1 hours;

                // Increase block time
                vm.warp(block.timestamp + timeIncrease);

                // Execute the performUpkeep function
                upkeep.performUpkeep();

                // Check if lastUpkeepTime has updated correctly
                assertEq(upkeep.lastUpkeepTime(), block.timestamp, "Incorrect lastUpkeepTime");
            	}
        }

    // A unit test to verify that upon deployment, the constructor sets the lastUpkeepTime to the current block's timestamp.
    function test_constructor() public {
			upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);

        assertEq(block.timestamp, upkeep.lastUpkeepTime(), "lastUpkeepTime was not set correctly in constructor");
    }


    // A unit test to verify that the performUpkeep function reverts when the block timestamp is less than the last upkeep time.
	function testPerformUpkeepRevertsWhenTimestampLTLastPerformUpkeep() public {
    	upkeep.performUpkeep();

    	vm.warp(block.timestamp - 1 minutes);

    	vm.expectRevert();
    	upkeep.performUpkeep();
    }


    // A unit test to verify that step1() functions correctly
    function testSuccessStep1() public
    	{
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

		// Step 1. Update the prices of BTC and ETH in the PriceAggregator.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1();

		assertEq( priceAggregator.getPriceBTC(), 20000 ether );
		assertEq( priceAggregator.getPriceETH(), 2000 ether );
    	}


    // A unit test to verify that step2() functions correctly
    function testSuccessStep2() public
    	{
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

		// Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step2();

		// Check that the WBTC and WETH have been sent for counterswap
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 50 ether );

		// Check that 20 ether of USDS has been burned
		assertEq( usds.totalSupply(), 10 ether );
    	}


    // A unit test to verify that step3() functions correctly
    function testSuccessStep3() public
    	{
    	// USDS to deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();

		// Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step3();

		// Check that the Upkeep contract withdrew USDS from counterswap
		assertEq( usds.balanceOf(address(upkeep)), 30 ether );
    	}


    // A unit test to verify that step4() functions correctly
    function testSuccessStep4() public
    	{
    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 25 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 25 ether);
    	pools.deposit(weth, 25 ether);
    	vm.stopPrank();

    	assertEq( pools.depositedBalance(address(dao), weth), 25 ether );

		// Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step4();

    	// Confirm the weth has been withdrawn and sent to the upkeep contract
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether );

    	assertEq( weth.balanceOf(address(upkeep)), 25 ether );
    	}


    // A unit test to verify that step5() functions correctly
    function testSuccessStep5() public
    	{
    	// Mimic withdrawing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(upkeep), 100 ether);

		// Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step5(alice);

    	assertEq( weth.balanceOf(alice), 5 ether );
    	}


    // A unit test to verify that step5() functions correctly
    function testSuccessStep5B() public
    	{
    	// Mimic withdrawing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(upkeep), 100 ether);

		// Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	vm.prank(address(alice));
    	upkeep.performUpkeep();

    	assertEq( weth.balanceOf(alice), 5 ether );
    	}


    // A unit test to verify that step6() functions correctly
    function testSuccessStep6() public
    	{
    	// Mimic withdrawing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(upkeep), 100 ether);

		// Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step6();

		// Check that the WETH has been sent to counterswap
		// Only half the specified percent will be used for USDS to form SALT/USDS POL (the other half will be counterswapped into SALT in step7)
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 10 ether );
    	}


    // A unit test to verify that step7() functions correctly
    function testSuccessStep7() public
    	{
    	// Mimic withdrawing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(upkeep), 100 ether);

		// Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step7();

		// Check that the WETH has been sent to counterswap
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 100 ether );
    	}


    // A unit test to verify that step8() functions correctly
    function testSuccessStep8() public
    	{
    	vm.prank(address(initialDistribution));
    	salt.transfer(address(usds), 15 ether);

    	vm.startPrank(address(usds));
    	salt.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 15 ether);
		vm.stopPrank();

		// Step 8. Withdraw SALT from previous counterswaps.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step8();

		// Check that the SALT has been sent to counterswap
    	assertEq( salt.balanceOf(address(upkeep)), 15 ether );
    	}


    // A unit test to verify that step9() functions correctly
    function testSuccessStep9() public
    	{
    	// SALT and USDS to the Upkeep contract
    	vm.prank(address(collateral));
    	usds.mintTo(address(upkeep), 30 ether );

    	vm.prank(address(initialDistribution));
    	salt.transfer(address(upkeep), 15 ether);

		// Check that the initial SALT/USDS reserves are zero
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq(reserve0, 0);
		assertEq(reserve1, 0);

		// Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step9();

		// Check that SALT/USDS POL has been formed
		(reserve0, reserve1) = pools.getPoolReserves(salt, usds);
		assertEq(reserve0, 15 ether);
		assertEq(reserve1, 30 ether);

		(bytes32 poolID,) = PoolUtils._poolID(salt, usds);

		// liquidity should hold the actually LP in the Pools contract
    	assertEq( pools.getUserLiquidity(address(liquidity), salt, usds), pools.totalLiquidity(poolID) );

		// The DAO should have full share of the liquidity
		assertEq( liquidity.userShareForPool(address(dao), poolID), pools.totalLiquidity(poolID) );
	  	}


    // A unit test to verify that step10() functions correctly
    function testSuccessStep10() public
    	{
    	// Mimics SALT that is already in the DAO
    	uint256 initialSaltInDAO = 1000 ether;

    	// SALT to the DAO (initialSaltInDAO and 15 ether which mimics step9() SALT being transferred from Upkeep to the DAO)
    	vm.startPrank(address(initialDistribution));
    	salt.transfer(address(dao), initialSaltInDAO + 15 ether);
    	vm.stopPrank();

		// Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step10(initialSaltInDAO);

		// SaltRewards should now have 15 ether (which doens't include the original amount in the DAO)
		assertEq( salt.balanceOf(address(saltRewards)), 15 ether );
	  	}


    // A unit test to verify that step11() functions correctly
    function testSuccessStep11() public
    	{
		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		assertEq( salt.balanceOf(address(emissions)), 52 * 1000000 ether );

    	uint256 timeElapsed = 1 days;

		// Step 11. Send SALT Emissions to the SaltRewards contract.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step11(timeElapsed);

		// Emissions initial distribution of 52 million tokens stored in the contract is a default .50% per week.
		// Approximately 37142 tokens per day initially.
		assertEq( salt.balanceOf(address(saltRewards)), 37142857142857142857142 );
	  	}


    // A unit test to verify that step12() functions correctly
    function testSuccessStep12() public
    	{
    	// Prepare
    	vm.startPrank(address(initialDistribution));
    	salt.approve(address(saltRewards), 100 ether);
    	saltRewards.addSALTRewards(100 ether);
    	salt.transfer(DEPLOYER, 1000000 ether);
    	vm.stopPrank();

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

		salt.approve(address(pools), type(uint256).max);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);

		// Place some sample trades to create arbitrage contributions for the pool stats
		pools.depositSwapWithdraw(salt, weth, 1 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(salt, wbtc, 1 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(weth, wbtc, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step12(poolIDs);

		// Check that 10% of the rewards were sent to the SALT/USDS liquidityRewardsEmitter
		bytes32[] memory poolIDsB = new bytes32[](1);
		(poolIDsB[0],) = PoolUtils._poolID(salt, usds);
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDsB)[0], 10 ether );

		// Check that rewards were sent to the stakingRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;
		assertEq( stakingRewardsEmitter.pendingRewardsForPools(poolIDsA)[0], 45 ether );

		// Check that rewards were sent proportionally to the three pools involved in generating the above arbitrage
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[0], uint256(45 ether) / 3 );
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[1], uint256(45 ether) / 3 );
		assertEq( liquidityRewardsEmitter.pendingRewardsForPools(poolIDs)[2], uint256(45 ether) / 3 );

		// Check that the rewards were reset
		uint256[] memory profitsForPools = IPoolStats(address(pools)).profitsForPools(poolIDs);
		for( uint256 i = 0; i < profitsForPools.length; i++ )
			assertEq( profitsForPools[i], 0 );
	  	}


    // A unit test to verify that step13() functions correctly
    function testSuccessStep13() public
    	{
    	// Prepare
    	vm.startPrank(address(initialDistribution));
    	salt.approve(address(saltRewards), 100 ether);
    	saltRewards.addSALTRewards(100 ether);
    	salt.transfer(DEPLOYER, 1000000 ether);
    	vm.stopPrank();

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

		salt.approve(address(pools), type(uint256).max);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);

		// Place some sample trades to create arbitrage contributions for the pool stats
		pools.depositSwapWithdraw(salt, weth, 1 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(salt, wbtc, 1 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(weth, wbtc, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step12(poolIDs);

		// Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step13(1 days);

		// Check if the rewards were transferred (default 1% per day...so 1% as the above timeSinceLastUpkeep is one day) to the liquidity contract
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], uint256(45 ether) / 300 );
		assertEq( rewards[1], uint256(45 ether) / 300 );
		assertEq( rewards[2], uint256(45 ether) / 300 );

		// Check that the staking rewards were transferred to the staking contract
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 45 ether / 100 );
	  	}


    // A unit test to verify that step14() functions correctly
    function testSuccessStep14() public
    	{
    	// SALT and USDS to the Upkeep contract
    	vm.prank(address(collateral));
    	usds.mintTo(address(upkeep), 30 ether );

    	vm.prank(address(initialDistribution));
    	salt.transfer(address(upkeep), 15 ether);

		// Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
    	vm.prank(address(upkeep));
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
		assertEq( salt.balanceOf(exchangeConfig.teamWallet()), 10 ether);

		// Check the amount burned
		uint256 amountBurned = initialSupply - salt.totalSupply();
		uint256 expectedAmountBurned = 90 ether * 75 / 100;
		assertEq( amountBurned, expectedAmountBurned );

		// Check that the remaining SALT stays in the DAO contract
		assertEq( salt.balanceOf(address(dao)), 90 ether - expectedAmountBurned );
	  	}


    // A unit test to verify that step15() functions correctly
    function testSuccessStep15() public
    	{
    	// Distribute the initial SALT tokens
    	vm.prank(address(bootstrapBallot));
    	initialDistribution.distributionApproved();

    	assertEq( salt.balanceOf(address(daoVestingWallet)), 25 * 1000000 ether );

		// Warp to the start of when the daoVestingWallet starts to emit
		vm.warp( daoVestingWallet.start() );

		vm.warp( block.timestamp + 24 hours );
		assertEq( salt.balanceOf(address(dao)), 0 );

		// Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step15();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );
    	}


    // A unit test to verify that step15() functions correctly after one year of delay
    function testSuccessStep15WithOneYearDelay() public
    	{
    	// Distribute the initial SALT tokens
    	vm.prank(address(bootstrapBallot));
    	initialDistribution.distributionApproved();

    	assertEq( salt.balanceOf(address(daoVestingWallet)), 25 * 1000000 ether );

		// Warp to the start of when the daoVestingWallet starts to emit
		vm.warp( daoVestingWallet.start() );

		vm.warp( block.timestamp + 60 * 60 * 24 * 365 );
		assertEq( salt.balanceOf(address(dao)), 0 );

		// Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step15();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours * 365 / (60 * 60 * 24 * 365 * 10) );
    	}


    // A unit test to verify that step16() functions correctly
    function testSuccessStep16() public
    	{
    	// Distribute the initial SALT tokens
    	vm.prank(address(bootstrapBallot));
    	initialDistribution.distributionApproved();

    	assertEq( salt.balanceOf(address(teamVestingWallet)), 10 * 1000000 ether );

		// Warp to the start of when the teamVestingWallet starts to emit
		vm.warp( teamVestingWallet.start() );

		vm.warp( block.timestamp + 24 hours );
		assertEq( salt.balanceOf(teamWallet), 0 );

		// Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step16();

		// Check that SALT has been sent to DAO.
    	assertEq( salt.balanceOf(teamWallet), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );
    	}


	// A unit test to verify all expected outcomes of a performUpkeep call
	function testComprehensivePerformUpkeep() public
		{
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

		// Need to warp so that there can be some SALT emissions
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


//		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();
//		uint256[] memory stats = IPoolStats(address(pools)).profitsForPools(poolIDs);
//		for( uint256 i = 0; i < poolIDs.length; i++ )
//			console.log( "POOL: ", stats[i] );


		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5 ether );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================

		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether );
		assertEq( priceAggregator.getPriceETH(), 2000 ether );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000 );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 310 ether );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 300 ether );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000 );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000 );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000 );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995 );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10) );


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
		upkeep.performUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0 );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 301000000000000000000 );
		assertEq( reserve1, 301000000000000000000 );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163436428571428571428571 );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000 );
		}



	// A unit test to verify all expected outcomes of a performUpkeep call
	function testComprehensivePerformUpkeepShortTimePeriod() public
		{
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
    	usds.mintTo( address(usds), 30000 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15000 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15000 ether);
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

		// Need to warp so that there can be some SALT emissions
		// 5 minutes delay will cause less SALT to be emitted which will cause the SALT/USDS POL formation to be limited by SALT rather than USDS
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 5 minutes);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );


//		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();
//		uint256[] memory stats = IPoolStats(address(pools)).profitsForPools(poolIDs);
//		for( uint256 i = 0; i < poolIDs.length; i++ )
//			console.log( "POOL: ", stats[i] );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================

		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		assertEq( priceAggregator.getPriceBTC(), 20000 ether );
		assertEq( priceAggregator.getPriceETH(), 2000 ether );

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000 );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 30010 ether );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30000 ether );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000 );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000 );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000 );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995 );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 5 minutes / (60 * 60 * 24 * 365 * 10) );

		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 5 minutes / (60 * 60 * 24 * 365 * 10) );


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
		vm.warp(block.timestamp + 5 minutes);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0 );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 25782343987823439878 );
		assertEq( reserve1, 25782343987823439878 );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 143070577876984126984127 );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 3762890625000000000000 );

   		// See how much SALT and USDS are left in the Upkeep contract
//   		console.log( "DAO SALT: ", salt.balanceOf(address(dao)) );
//   		console.log( "DAO USDS: ", usds.balanceOf(address(dao)) );
		}
	}
