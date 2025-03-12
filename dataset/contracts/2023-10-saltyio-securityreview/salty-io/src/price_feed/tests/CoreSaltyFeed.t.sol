// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";
import "../CoreSaltyFeed.sol";


contract TestCoreSaltyFeed is Deployment
	{
	CoreSaltyFeed public saltyFeed;


	constructor()
		{
		saltyFeed = new CoreSaltyFeed( pools, exchangeConfig );

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		vm.startPrank(DEPLOYER);
       	wbtc.approve( address(pools), type(uint256).max );
       	weth.approve( address(pools), type(uint256).max );
       	usds.approve( address(pools), type(uint256).max );

		vm.stopPrank();

		vm.prank( address(collateral) );
		usds.mintTo(DEPLOYER, 1000000000 ether);

		finalizeBootstrap();

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);
		}


	// Assumes no initial liquidity
	function setPriceInPoolsWBTC( uint256 price ) public
		{
		vm.startPrank(DEPLOYER);
		pools.addLiquidity( wbtc, usds, 1000 * 10**8, price * 1000, 0, block.timestamp );
		vm.stopPrank();
		}


	// Assumes no initial liquidity
	function setPriceInPoolsWETH( uint256 price ) public
		{
		vm.startPrank(DEPLOYER);
		pools.addLiquidity( weth, usds, 1000 ether, price * 1000, 0, block.timestamp );
		vm.stopPrank();
		}


	// A unit test that verifies the correct operation of getPriceBTC and getPriceETH functions when the reserves of WBTC/WETH and USDS are above the DUST limit. The test should set the reserves to known values and check that both functions return the expected price. Additionally, this test should cover scenarios where the pool reserves fluctuate or are updated in real-time.
	function testCorrectOperationOfGetPriceBTCAndETHWithSufficientReserves() public
        {
        uint256 wbtcPrice = 50000 ether; // WBTC price in terms of USDS
        uint256 wethPrice = 3000 ether;  // WETH price in terms of USDS

        // Set prices in the pools
        this.setPriceInPoolsWBTC(wbtcPrice);
        this.setPriceInPoolsWETH(wethPrice);

        // Prices should match those set in the pools
        assertEq(saltyFeed.getPriceBTC(), wbtcPrice, "Incorrect WBTC price returned");
        assertEq(saltyFeed.getPriceETH(), wethPrice, "Incorrect WETH price returned");

		// Remove all liquidity before changing price
		vm.startPrank( DEPLOYER );
		pools.removeLiquidity( wbtc, usds, pools.getUserLiquidity(DEPLOYER, wbtc, usds), 0, 0, block.timestamp );
		pools.removeLiquidity( weth, usds, pools.getUserLiquidity(DEPLOYER, weth, usds), 0, 0, block.timestamp );
		vm.stopPrank();

        // Change reserves to simulate real-time update
        uint256 newWbtcPrice = 55000 ether;
        uint256 newWethPrice = 3200 ether;

        this.setPriceInPoolsWBTC(newWbtcPrice);
        this.setPriceInPoolsWETH(newWethPrice);

        // Prices should reflect new reserves
        assertEq(saltyFeed.getPriceBTC(), newWbtcPrice, "Incorrect WBTC price returned after reserves update");
        assertEq(saltyFeed.getPriceETH(), newWethPrice, "Incorrect WETH price returned after reserves update");
        }


	// A unit test that confirms that getPriceBTC and getPriceETH functions return zero when the reserves of WBTC/WETH or USDS are equal to or below the DUST limit, regardless of the other's reserves.
	function testGetPriceReturnsZeroWithDustReserves() public
		{
		// Set prices in the pools with dust reserve
		this.setPriceInPoolsWBTC(1 ether);
		this.setPriceInPoolsWETH(1 ether);

		// Remove all liquidity except for DUST amount
		vm.startPrank( DEPLOYER );
		pools.removeLiquidity( wbtc, usds, pools.getUserLiquidity(DEPLOYER, wbtc, usds) - PoolUtils.DUST + 1, 0, 0, block.timestamp );
		pools.removeLiquidity( weth, usds, pools.getUserLiquidity(DEPLOYER, weth, usds) - PoolUtils.DUST + 1, 0, 0, block.timestamp );
		vm.stopPrank();

		// Prices should be zero due to DUST limit
		assertEq(saltyFeed.getPriceBTC(), 0, "Price for WBTC should be zero when reserves are DUST");
		assertEq(saltyFeed.getPriceETH(), 0, "Price for WETH should be zero when reserves are DUST");
		}


	// A unit test that checks if the contract behaves as expected when the WBTC, WETH, or USDS token contract addresses are invalid or manipulated. This could include scenarios where the token contracts do not implement the expected ERC20 interface, or when the token contracts behave maliciously.
	function testInvalidTokens() public
		{
	    exchangeConfig = new ExchangeConfig( ISalt(address(0x1)), IERC20(address(0x1)), IERC20(address(0x1)), IERC20(address(0x1)), IUSDS(address(0x2)), teamWallet);
		saltyFeed = new CoreSaltyFeed(pools, exchangeConfig );

	    // Prices should match those set in the pools
        assertEq(saltyFeed.getPriceBTC(), 0, "Incorrect WBTC price returned");
        assertEq(saltyFeed.getPriceETH(), 0, "Incorrect WETH price returned");
	}


	// A unit test that validates that initializing the CoreSaltyFeed contract with zero addresses for the IPools or IExchangeConfig contracts fails as expected.
	    // A unit test that validates that initializing the CoreSaltyFeed contract with zero addresses for the IPools or IExchangeConfig contracts fails as expected.
        function testCoreSaltyFeedInitializationWithZeroAddresses() public
            {
            // Initialize with zero IPools address
            vm.expectRevert("_pools cannot be address(0)");
            new CoreSaltyFeed(IPools(address(0)), exchangeConfig);

            // Initialize with zero IExchangeConfig address
            vm.expectRevert("_exchangeConfig cannot be address(0)");
            new CoreSaltyFeed(pools, IExchangeConfig(address(0)));
            }


	// A unit test that verifies the correct initialization of the pools, WBTC, WETH, and USDS contract addresses in the CoreSaltyFeed constructor.
	function testCorrectInitializationOfContractAddresses() public
		{
		assertEq(address(saltyFeed.pools()), address(pools), "Pools address not correctly initialized");
		assertEq(address(saltyFeed.wbtc()), address(wbtc), "WBTC address not correctly initialized");
		assertEq(address(saltyFeed.weth()), address(weth), "WETH address not correctly initialized");
		assertEq(address(saltyFeed.usds()), address(usds), "USDS address not correctly initialized");
		}

	// A unit test that validates that getPriceBTC function does not revert in case of zero reserves for WBTC and USDS.
	function testGetPriceBTCDoesNotRevertWithZeroReserves() public
    {
        // Call getPriceBTC, should not revert and should return 0
        assertEq(saltyFeed.getPriceBTC(), 0, "Price for WBTC should be zero when reserves are zero");
    }


    // A unit test that validates that getPriceETH function does not revert in case of zero reserves for WETH and USDS.
	function testGetPriceETHDoesNotRevertWithZeroReserves() public
    {
        // Call getPriceETH, should not revert and should return 0
        assertEq(saltyFeed.getPriceETH(), 0, "Price for WETH should be zero when reserves are zero");
    }


    // A unit test to verify the getPriceBTC functions return a non-zero value when reserves of WBTC/WETH are just above the DUST limit and USDS reserves are substantially high.
    function testLargeUSDSReservesBTC() public
        {
        uint256 btcPrice = 30000 ether;  // BTC price in terms of USDS

		vm.startPrank(DEPLOYER);
		pools.addLiquidity( wbtc, usds, PoolUtils.DUST + 1, btcPrice * (PoolUtils.DUST + 1), 0, block.timestamp );
		vm.stopPrank();

        // Prices should match those set in the pools
        assertEq(saltyFeed.getPriceBTC(), btcPrice * 10**8, "Incorrect WBTC price returned");
        }


    // A unit test to verify the getPriceETH functions return a non-zero value when reserves of WBTC/WETH are just above the DUST limit and USDS reserves are substantially high.
    function testLargeUSDSReservesETH() public
        {
        uint256 ethPrice = 3000 ether;  // ETH price in terms of USDS

		vm.startPrank(DEPLOYER);
		pools.addLiquidity( weth, usds, PoolUtils.DUST + 1, ethPrice * (PoolUtils.DUST + 1), 0, block.timestamp );
		vm.stopPrank();

        // Prices should match those set in the pools
        assertEq(saltyFeed.getPriceETH(), ethPrice * 10**18, "Incorrect WETH price returned");
        }


    // A unit test that checks whether getPriceBTC and getPriceETH functions can handle a division by zero error.
    function testDivisionByZero() public
    {
        // Set prices in the pools with dust reserve
        this.setPriceInPoolsWBTC(1 ether);
        this.setPriceInPoolsWETH(1 ether);

        // Remove all liquidity except for 1, which is less than DUST
        vm.startPrank( DEPLOYER );
        pools.removeLiquidity( wbtc, usds, pools.getUserLiquidity(DEPLOYER, wbtc, usds) - 1, 0, 0, block.timestamp );
        pools.removeLiquidity( weth, usds, pools.getUserLiquidity(DEPLOYER, weth, usds) - 1, 0, 0, block.timestamp );
        vm.stopPrank();

        // Prices should be zero due to DUST limit
        assertEq(saltyFeed.getPriceBTC(), 0, "Price for WBTC should be zero when reserves are less than DUST");
        assertEq(saltyFeed.getPriceETH(), 0, "Price for WETH should be zero when reserves are less than DUST");
    }


    // A unit test to confirm that getPriceBTC and getPriceETH function returns are consistent if reserves do not change.
    function testGetPriceConsistency() public
    		{
    			// Set known reserves in pools
    			uint256 wbtcPrice = 40000 ether; // WBTC price in terms of USDS
            	uint256 wethPrice = 2000 ether;  // WETH price in terms of USDS

    			this.setPriceInPoolsWBTC(wbtcPrice);
    			this.setPriceInPoolsWETH(wethPrice);

    			uint256 initialPriceBTC = saltyFeed.getPriceBTC();
    			uint256 initialPriceETH = saltyFeed.getPriceETH();

    			assertEq(initialPriceBTC, wbtcPrice, "Price BTC changed over time without reserve changes");
    			assertEq(initialPriceETH, wethPrice, "Price ETH changed over time without reserve changes");

    			// Simulate passing of time without changing reserves
    		    vm.warp(block.timestamp + 60 * 60 * 24);

    			// Prices should be consistant over time if reserves do not change
    			assertEq(initialPriceBTC, saltyFeed.getPriceBTC(), "Price BTC changed over time without reserve changes");
    			assertEq(initialPriceETH, saltyFeed.getPriceETH(), "Price ETH changed over time without reserve changes");
    		}


    // A unit test that verifies if the getPriceBTC and getPriceETH functions handle accurately when reserves of WBTC/WETH or USDS are excessively small.
    function testGetPriceWithExcessivelySmallReserves() public
    		{
    		// Set prices in the pools with very small reserve
    		this.setPriceInPoolsWBTC(1);
    		this.setPriceInPoolsWETH(1);

			// Remove all liquidity except for 1, which is less than DUST
			vm.startPrank( DEPLOYER );
			pools.removeLiquidity( wbtc, usds, pools.getUserLiquidity(DEPLOYER, wbtc, usds) - 1, 0, 0, block.timestamp );
			pools.removeLiquidity( weth, usds, pools.getUserLiquidity(DEPLOYER, weth, usds) - 1, 0, 0, block.timestamp );
			vm.stopPrank();

    		// Prices should be zero due to small reserves
    		assertEq(saltyFeed.getPriceBTC(), 0, "Price for WBTC should be zero when reserves are too small");
    		assertEq(saltyFeed.getPriceETH(), 0, "Price for WETH should be zero when reserves are too small");

    		// Remove all liquidity
    		vm.startPrank( DEPLOYER );
    		pools.removeLiquidity( wbtc, usds, pools.getUserLiquidity(DEPLOYER, wbtc, usds), 0, 0, block.timestamp );
    		pools.removeLiquidity( weth, usds, pools.getUserLiquidity(DEPLOYER, weth, usds), 0, 0, block.timestamp );
    		vm.stopPrank();

    		// Prices should still be zero
    		assertEq(saltyFeed.getPriceBTC(), 0, "Price for WBTC should still be zero after removing liquidity");
    		assertEq(saltyFeed.getPriceETH(), 0, "Price for WETH should still be zero after removing liquidity");
    		}
	}