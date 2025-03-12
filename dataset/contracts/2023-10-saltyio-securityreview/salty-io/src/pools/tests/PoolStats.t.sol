// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../Pools.sol";
import "../../dev/Deployment.sol";
import "../PoolStats.sol";
import "../PoolUtils.sol";
import "../../root_tests/TestERC20.sol";


contract TestPoolStats is Test, PoolStats
	{
	Deployment public deployment = new Deployment();

	IERC20 public wbtc = deployment.wbtc();

	IERC20 public tokenA = new TestERC20("TEST", 6);
	IERC20 public tokenB = new TestERC20("TEST", 18);
	IERC20 public tokenC = new TestERC20("TEST", 18);

	bytes32 public poolID;
	bytes32 public poolID2;


	constructor()
	PoolStats(deployment.exchangeConfig())
		{
		// Different decimals
		(poolID,) = PoolUtils._poolID( tokenA, tokenB );

		// Same decimals
		(poolID2,) = PoolUtils._poolID( tokenB, tokenC );
		}


	// A unit test to determine that the initial alpha is calculated correctly (about 0.0011104942 for 30 minutes)
	function testConstants() public
		{
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( alpha, ABDKMathQuad.fromUInt(10**18)) ), 1110494169905607 );
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( ONE, ABDKMathQuad.fromUInt(10**18)) ), 1000000000000000000 );
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( ZERO, ABDKMathQuad.fromUInt(10**18)) ), 0 );
		}


	// A unit test where a single pool is updated multiple times, with varying reserve0 and reserve1 values. This test should verify that the averageReserveRatios and lastUpdateTimes are updated correctly. Specifically, the test should check that the exponential moving average calculation is correct, and that the last update time is set to the current block timestamp.
	function testUpdatePoolStatsMultipleTimes() public
    	{
		bytes16 actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 0 );

   		_updatePoolStats(poolID, 1 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 500000000000000000 );
   		assertEq( lastUpdateTimes[poolID], block.timestamp );

		// No delay in time has no effect on the average
   		_updatePoolStats(poolID, 2 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 500000000000000000 );
   		assertEq( lastUpdateTimes[poolID], block.timestamp );

		vm.warp( block.timestamp + 30 seconds );

   		_updatePoolStats(poolID, 2 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 516657412548584119 );
  		assertEq( lastUpdateTimes[poolID], block.timestamp );

		vm.warp( block.timestamp + 5 minutes );

   		_updatePoolStats(poolID, 10 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 3676016408923292353 );
  		assertEq( lastUpdateTimes[poolID], block.timestamp );

		vm.warp( block.timestamp + 15 minutes );

   		_updatePoolStats(poolID, 10 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 9996488626545765292 );
  		assertEq( lastUpdateTimes[poolID], block.timestamp );

		vm.warp( block.timestamp + 30 minutes );

		// Large delay will cause the effective alpha to max at 1 and ignore all previous data
   		_updatePoolStats(poolID, 20 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 20000000000000000000 );
  		assertEq( lastUpdateTimes[poolID], block.timestamp );

//		console.log( "Ratio: ", ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ) );
    	}


	// A unit test where a single pool is updated multiple times, with varying reserve0 and reserve1 values. This test should verify that the averageReserveRatios and lastUpdateTimes are updated correctly. Specifically, the test should check that the exponential moving average calculation is correct, and that the last update time is set to the current block timestamp.
	function testUpdatePoolStatsMultipleTimes2() public
    	{
		bytes16 actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 0 );

   		_updatePoolStats(poolID2, 1 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 500000000000000000 );
   		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		// No delay in time has no effect on the average
   		_updatePoolStats(poolID2, 2 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 500000000000000000 );
   		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		vm.warp( block.timestamp + 30 seconds );

   		_updatePoolStats(poolID2, 2 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 516657412548584119 );
  		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		vm.warp( block.timestamp + 5 minutes );

   		_updatePoolStats(poolID2, 10 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 3676016408923292353 );
  		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		vm.warp( block.timestamp + 15 minutes );

   		_updatePoolStats(poolID2, 10 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 9996488626545765292 );
  		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		vm.warp( block.timestamp + 30 minutes );

		// Large delay will cause the effective alpha to max at 1 and ignore all previous data
   		_updatePoolStats(poolID2, 20 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 20000000000000000000 );
  		assertEq( lastUpdateTimes[poolID2], block.timestamp );

//		console.log( "Ratio: ", ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ) );
    	}



	// A unit test for `_updatePoolStats` that checks the function does not update stats for pools with reserve0 or reserve1 below the dust limit
	function testUpdatePoolStatsIgnored() public
    {
        // Reserves below dust limit
        _updatePoolStats(poolID, 0, PoolUtils.DUST);
        assertEq( lastUpdateTimes[poolID], 0 );

		vm.warp(block.timestamp + 1 hours);

        // Reserves equal to dust limit
        _updatePoolStats(poolID, PoolUtils.DUST, PoolUtils.DUST);
        assertEq( lastUpdateTimes[poolID], block.timestamp );

        // Reserves just above dust limit
        _updatePoolStats(poolID, PoolUtils.DUST+1, PoolUtils.DUST+1);
        assertEq( lastUpdateTimes[poolID], block.timestamp );
    }


    // A unit test for `_updateProfitsFromArbitrage` that verifies the function ignores cases without arbitrage profit
    function testUpdateProfitsFromArbitrage_IgnoreNoProfitCase() public
    	{
        bool isWhitelistedPair = true;
        IERC20 arbToken2 = tokenA;
        IERC20 arbToken3 = tokenB;
        uint256 initialProfit;
        uint256 arbitrageProfit = 0;  // no profit

        (poolID,) = PoolUtils._poolID( arbToken2, arbToken3 );
        initialProfit = _profitsForPools[poolID];

        _updateProfitsFromArbitrage(isWhitelistedPair, arbToken2, arbToken3, wbtc, exchangeConfig.weth(), arbitrageProfit);

        assertEq(_profitsForPools[poolID], initialProfit, "Profit should not increase when arbitrage profit is zero");
    	}


	// A unit test for `_updateProfitsFromArbitrage` that verifies the function updates profits for whitelisted pairs correctly
	function testUpdateProfitsFromArbitrage_WhitelistedPair() public {
        bool isWhitelistedPair = true;
        IERC20 arbToken2 = tokenA;
        IERC20 arbToken3 = tokenB;
        uint256 arbitrageProfit = 1 ether;

        (poolID,) = PoolUtils._poolID( arbToken2, arbToken3 );

        uint256 initialProfit = _profitsForPools[poolID];

        _updateProfitsFromArbitrage(isWhitelistedPair, arbToken2, arbToken3, wbtc, exchangeConfig.weth(), arbitrageProfit);

        assertEq(_profitsForPools[poolID], initialProfit + arbitrageProfit / 3, "Profit didn't increase as expected for whitelisted pair");
    }


	// A unit test for `_updateProfitsFromArbitrage` that checks the function updates profits for non-whitelisted pairs correctly
	 function testUpdateProfitsFromArbitrage_UpdateNonWhitelistedPairs() public
     {
        bool isWhitelistedPair = false;
        uint256 arbitrageProfit = 1 ether;  // profit

        _updateProfitsFromArbitrage(isWhitelistedPair, tokenA, tokenC, wbtc, exchangeConfig.weth(), arbitrageProfit);

        (bytes32 poolIDA,) = PoolUtils._poolID( tokenA, wbtc );
        (bytes32 poolIDB,) = PoolUtils._poolID( tokenC, wbtc );

        // Check that the profits for the non-whitelisted pairs are updated correctly
        assertEq(_profitsForPools[poolIDA], arbitrageProfit / 4, "Profit for the second pair should be updated");
        assertEq(_profitsForPools[poolIDB], arbitrageProfit / 4, "Profit for the second pair should be updated");
    }


	// A unit test for `clearProfitsForPools` that verifies the function clears the profits for given pool IDs correctly
	function testClearProfitsForPools() public {
        // Assume initial profits
        _profitsForPools[poolID] = 1 ether;
        _profitsForPools[poolID2] = 2 ether;

        // Check initial profits
        assertEq(_profitsForPools[poolID], 1 ether);
        assertEq(_profitsForPools[poolID2], 2 ether);

        // Clear profits for the first pool
        bytes32[] memory poolIDs = new bytes32[](1);
        poolIDs[0] = poolID;
		vm.prank(address(deployment.upkeep()));
        this.clearProfitsForPools(poolIDs);

        // Check that the profits for the first pool are cleared
        assertEq(_profitsForPools[poolID], 0);
        assertEq(_profitsForPools[poolID2], 2 ether);

        // Clear profits for the second pool
        poolIDs[0] = poolID2;
		vm.prank(address(deployment.upkeep()));
        this.clearProfitsForPools(poolIDs);

        // Check that the profits for the second pool are cleared
        assertEq(_profitsForPools[poolID], 0);
        assertEq(_profitsForPools[poolID2], 0);
    }


	// A unit test for `clearProfitsForPools` that verifies an exception is thrown when an unauthorized account tries to call it
	function testClearProfitsForPoolsNotAuthorized() public {
        bytes32[] memory poolIDs = new bytes32[](1);
        (poolIDs[0],) = PoolUtils._poolID(tokenA, tokenB);

        vm.expectRevert("PoolStats.clearProfitsForPools is only callable from the Upkeep contract");
        this.clearProfitsForPools(poolIDs);
    }


	// A unit test for `clearProfitsForPools` that verifies the function does not clear profits for non-provided pool ids
		function testClearProfitsForNonProvidedPools() public {
    		bytes32[] memory poolIDs = new bytes32[](2);
    		poolIDs[0] = poolID;
    		poolIDs[1] = poolID2;

    		_profitsForPools[poolID] = 100 ether;
    		_profitsForPools[poolID2] = 50 ether;

    		bytes32[] memory providedPools = new bytes32[](1);
    		providedPools[0] = poolID;

			vm.prank(address(deployment.upkeep()));
    		this.clearProfitsForPools(providedPools);

    		uint256 pool1profit = _profitsForPools[poolID];
    		uint256 pool2profit = _profitsForPools[poolID2];

    		assertEq(pool1profit, 0, "Expect clearProfitsForPools to clear profits for the supplied pool ID");
    		assertEq(pool2profit, 50 ether, "Expect clearProfitsForPools to leave profits unchanged for not supplied pool ID");
    	}


	// A unit test for `profitsForPools` that verifies it returns profits correctly for given pool IDs
	function testProfitsForPools() public {

		_updateProfitsFromArbitrage(true, tokenA, tokenB, wbtc, exchangeConfig.weth(), 10 ether); // 10 ether profit for arbToken2/arbToken3 pool
		_updateProfitsFromArbitrage(true, tokenB, tokenC, wbtc, exchangeConfig.weth(), 5 ether); // 5 ether profit for arbToken2/arbToken3 pool

		bytes32[] memory poolIDs = new bytes32[](6);
		(poolIDs[0],) = PoolUtils._poolID(tokenA, tokenB);
		(poolIDs[1],) = PoolUtils._poolID(tokenA, exchangeConfig.weth());
		(poolIDs[2],) = PoolUtils._poolID(tokenB, exchangeConfig.weth());

		(poolIDs[3],) = PoolUtils._poolID(tokenB, tokenC);
		(poolIDs[4],) = PoolUtils._poolID(tokenB, exchangeConfig.weth());
		(poolIDs[5],) = PoolUtils._poolID(tokenC, exchangeConfig.weth());

		uint256[] memory profits = this.profitsForPools(poolIDs);

		assertEq(profits[0], uint256(10 ether) / 3, "Incorrect profit for pool 0a");
		assertEq(profits[1], uint256(10 ether) / 3, "Incorrect profit for pool 0b");
		assertEq(profits[2], uint256(10 ether) / 3 + uint256(5 ether) / 3, "Incorrect profit for pool 0c");

		assertEq(profits[3], uint256(5 ether) / 3, "Incorrect profit for pool 1a");
		assertEq(profits[4], uint256(10 ether) / 3 + uint256(5 ether) / 3, "Incorrect profit for pool 1b");
		assertEq(profits[5], uint256(5 ether) / 3, "Incorrect profit for pool 1c");

		// Clear the profits
		vm.prank(address(deployment.upkeep()));
		this.clearProfitsForPools(poolIDs);

		profits = this.profitsForPools(poolIDs);
		assertEq(profits[0], 0, "Profit for pool 0 not cleared");
		assertEq(profits[1], 0, "Profit for pool 0 not cleared");
		assertEq(profits[2], 0, "Profit for pool 0 not cleared");

		assertEq(profits[3], 0, "Profit for pool 1 not cleared");
		assertEq(profits[4], 0, "Profit for pool 1 not cleared");
		assertEq(profits[5], 0, "Profit for pool 1 not cleared");
	}


	// A unit test for `profitsForPools` that verifies it returns zero for pools without profits
	function testPoolWithoutProfits() public
	{
		(bytes32 _poolID2,) = PoolUtils._poolID( tokenA, tokenB );
		// Checking initial profit of pool to be zero
		assertEq(_profitsForPools[_poolID2], 0, "Initial profit should be zero");
	}


   // A unit test for averageReserveRatio() function that verifies the ratio is inverted/flipped if provided tokens are flipped
   function testAverageReserveRatio() public {
       // Prepare
       _updatePoolStats(poolID2, 2 ether, 3 ether);
       bytes16 expectedRatio = ABDKMathQuad.div( ABDKMathQuad.fromUInt(3 ether), ABDKMathQuad.fromUInt(2 ether) );

       // Execute and verify
       bytes16 actualRatio = averageReserveRatio( tokenB, tokenC );

       assertEq(
           ABDKMathQuad.toUInt(ABDKMathQuad.mul(actualRatio, ABDKMathQuad.fromUInt(1 ether))),
           ABDKMathQuad.toUInt(ABDKMathQuad.mul(expectedRatio, ABDKMathQuad.fromUInt(1 ether))),
           "Reserve ratios don't match"
       );

       // Execute and verify inverse check. We need to invert the expected ratio as now tokenC is the first token and tokenB the second token
       actualRatio = averageReserveRatio( tokenC, tokenB );

       expectedRatio = ABDKMathQuad.div( ABDKMathQuad.fromUInt(1), expectedRatio );
       assertEq(
           ABDKMathQuad.toUInt(ABDKMathQuad.mul(actualRatio, ABDKMathQuad.fromUInt(1 ether))),
           ABDKMathQuad.toUInt(ABDKMathQuad.mul(expectedRatio, ABDKMathQuad.fromUInt(1 ether))),
           "Flipped reserve ratios don't match"
       );
   }


	// A unit test to check constructor that throws error when exchangeConfig address is equal to zero
	function testConstructorAddressZero() public
    {
    vm.expectRevert( "_exchangeConfig cannot be address(0)" );
    new PoolStats(IExchangeConfig(address(0)));
    }

	}

