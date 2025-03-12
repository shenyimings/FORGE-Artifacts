// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";
import "./ForcedPriceFeed.sol";
import "./TestPriceAggregator.sol";


contract TestPriceAggreagator is Deployment
	{
	IForcedPriceFeed public priceFeed1;
	IForcedPriceFeed public priceFeed2;
	IForcedPriceFeed public priceFeed3;


	constructor()
 		{
 		priceFeed1 = new ForcedPriceFeed(30000 ether, 3000 ether );
 		priceFeed2 = new ForcedPriceFeed(30100 ether, 3050 ether );
 		priceFeed3 = new ForcedPriceFeed(30500 ether, 3010 ether );

		priceAggregator = new PriceAggregator();
		priceAggregator.setInitialFeeds( IPriceFeed(address(priceFeed1)), IPriceFeed(address(priceFeed2)), IPriceFeed(address(priceFeed3)) );
		}


	// A unit test that verifies the correct operation of the setInitialFeeds function. This test should check that the function correctly sets the initial price feeds, that it cannot be called more than once, and that it reverts if any of the price feed addresses are zero.
	function testSetInitialFeeds() public
    {
        // Setup
        IPriceFeed newPriceFeed1 = IPriceFeed(address(new ForcedPriceFeed(1 ether, 1 ether)));
        IPriceFeed newPriceFeed2 = IPriceFeed(address(new ForcedPriceFeed(2 ether, 2 ether)));
        IPriceFeed newPriceFeed3 = IPriceFeed(address(new ForcedPriceFeed(3 ether, 3 ether)));

        PriceAggregator newPriceAggregator = new PriceAggregator();

        // Test successful call
        newPriceAggregator.setInitialFeeds(newPriceFeed1, newPriceFeed2, newPriceFeed3);
        assertEq(address(newPriceAggregator.priceFeed1()), address(newPriceFeed1));
        assertEq(address(newPriceAggregator.priceFeed2()), address(newPriceFeed2));
        assertEq(address(newPriceAggregator.priceFeed3()), address(newPriceFeed3));

        // Test revert when function is called more than once
        vm.expectRevert("setInitialFeeds() can only be called once");
        newPriceAggregator.setInitialFeeds(newPriceFeed1, newPriceFeed2, newPriceFeed3);

        // Test revert when any of the price feed addresses are zero
        newPriceAggregator = new PriceAggregator();
        vm.expectRevert("_priceFeed1 cannot be address(0)");
        newPriceAggregator.setInitialFeeds(IPriceFeed(address(0)), newPriceFeed2, newPriceFeed3);

        vm.expectRevert("_priceFeed2 cannot be address(0)");
        newPriceAggregator.setInitialFeeds(newPriceFeed1, IPriceFeed(address(0)), newPriceFeed3);

        vm.expectRevert("_priceFeed3 cannot be address(0)");
        newPriceAggregator.setInitialFeeds(newPriceFeed1, newPriceFeed2, IPriceFeed(address(0)));
    }


	// A unit test that checks the operation of the _aggregatePrices function. Should only be tested through external calls. This test should verify that the function correctly aggregates the prices from the price feeds when only two of the price feeds return non-zero prices, that it reverts if there are not at least two non-zero prices or if the closest two prices are more than the maximum allowed difference apart, and that the function correctly calculates the average of the two non-zero prices.
	function testAggregatePrices() public
    {
        // Setup
        priceFeed1.setBTCPrice(0 ether);  // Setting 0 price to priceFeed1
        priceFeed2.setBTCPrice(50000 ether);  // Setting a price to priceFeed2
        priceFeed3.setBTCPrice(51000 ether);  // Setting a price close to priceFeed2 to priceFeed3

        // Test aggregating the prices correctly from the price feeds when only two of the price feeds return non-zero prices
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 50500 ether);  // The average of priceFeed2 and priceFeed3

        // Test reverts if there are not at least two non-zero prices
        priceFeed2.setBTCPrice(0 ether);  // Setting 0 price to priceFeed2 as well
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

        // Test reverts if the closest two prices are more than the maximum allowed difference apart
        priceFeed2.setBTCPrice(50000 ether);  // Resetting priceFeed2's price
        priceFeed3.setBTCPrice(52600 ether);  // Setting a price more than 5% different from priceFeed2 to priceFeed3
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

        // Test correctly calculates the average of the two non-zero prices
        priceFeed3.setBTCPrice(51000 ether);  // Resetting priceFeed3's price
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 50500 ether);  // The average of priceFeed2 and priceFeed3

		// Test price1 and price2 the closest and within range
        priceFeed1.setBTCPrice(50100 ether);
        priceFeed2.setBTCPrice(50000 ether);
        priceFeed3.setBTCPrice(50200 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 50050 ether);  // The average of priceFeed1 and priceFeed2

		// Test price2 and price3 the closest and within range
        priceFeed1.setBTCPrice(49000 ether);
        priceFeed2.setBTCPrice(50100 ether);
        priceFeed3.setBTCPrice(50200 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 50150 ether);  // The average of priceFeed2 and priceFeed3

		// Test price1 and price3 the closest and within range
        priceFeed1.setBTCPrice(49000 ether);
        priceFeed2.setBTCPrice(52100 ether);
        priceFeed3.setBTCPrice(50000 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices
        assertEq(priceAggregator.getPriceBTC(), 49500 ether);  // The average of priceFeed1 and priceFeed3




		// Test price1 and price2 the closest and out of range
        priceFeed1.setBTCPrice(52600 ether);
        priceFeed2.setBTCPrice(50000 ether);
        priceFeed3.setBTCPrice(0 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

		// Test price2 and price3 the closest and out of range
        priceFeed1.setBTCPrice(0 ether);
        priceFeed2.setBTCPrice(50000 ether);
        priceFeed3.setBTCPrice(52600 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

		// Test price1 and price3 the closest and out of range
        priceFeed1.setBTCPrice(52600 ether);
        priceFeed2.setBTCPrice(0 ether);
        priceFeed3.setBTCPrice(50000 ether);
        priceAggregator.performUpkeep();  // This will internally call _aggregatePrices

        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();
    }

    // A unit test for the setPriceFeed function. It should validate the function only calls if the cooldown period is met, also checking that the 1, 2 or 3 PriceFeed is updated accordingly and the timestamp changes.
    function testSetPriceFeed() public
        {
            // Prepare a new price feed to set in place of the current price feed
            IPriceFeed newPriceFeed = IPriceFeed(address(new ForcedPriceFeed(1 ether, 1 ether)));

    		// Test setPriceFeed when cooldown period is met
            vm.warp( block.timestamp + priceAggregator.setPriceFeedCooldown() );
            priceAggregator.setPriceFeed(1, newPriceFeed);
            assertEq(address(priceAggregator.priceFeed1()), address(newPriceFeed));

            // Set priceFeed2 and priceFeed3 to newPriceFeed
            vm.warp( block.timestamp + priceAggregator.setPriceFeedCooldown() );
            priceAggregator.setPriceFeed(2, newPriceFeed);
            assertEq(address(priceAggregator.priceFeed2()), address(newPriceFeed));

            vm.warp( block.timestamp + priceAggregator.setPriceFeedCooldown() );
            priceAggregator.setPriceFeed(3, newPriceFeed);
            assertEq(address(priceAggregator.priceFeed3()), address(newPriceFeed));

            // Test revert when setPriceFeed is invoked before cooldown period is met
            IPriceFeed anotherPriceFeed = IPriceFeed(address(new ForcedPriceFeed(2 ether, 2 ether)));

			// Test that price feeds don't change if not meeting the cooldown
            priceAggregator.setPriceFeed(1, anotherPriceFeed);
            assertEq(address(priceAggregator.priceFeed1()), address(newPriceFeed));

            priceAggregator.setPriceFeed(2, anotherPriceFeed);
            assertEq(address(priceAggregator.priceFeed2()), address(newPriceFeed));

            priceAggregator.setPriceFeed(3, anotherPriceFeed);
            assertEq(address(priceAggregator.priceFeed3()), address(newPriceFeed));

        }


    // A unit test that confirms the _absoluteDifference operation handles x and y with x > y, x < y and x == y
	function testAbsoluteDifference() public
    	{
    	TestPriceAggregator tpa = new TestPriceAggregator();

		// Test x > y
		uint256 result = tpa.absoluteDifference(10 ether, 5 ether);
		assertEq(result, 5 ether, "Incorrect absolute difference computed for 10 ether and 5 ether");

		// Test x < y
		result = tpa.absoluteDifference(5 ether, 10 ether);
		assertEq(result, 5 ether, "Incorrect absolute difference computed for 5 ether and 10 ether");

		// Test x == y
		result = tpa.absoluteDifference(10 ether, 10 ether);
		assertEq(result, 0 ether, "Incorrect absolute difference computed for 10 ether and 10 ether");
    	}


    // A unit test that checks the _getPriceBTC and _getPriceETH functions. It should confirm whether the functions catch an error when the price is not retrievable and emits the appropriate event (PriceFeedError).
    function testPriceRetrieval() public {

    	priceAggregator.performUpkeep();

        // Check initial prices
        assertEq(priceAggregator.getPriceBTC(), 30050 ether);
        assertEq(priceAggregator.getPriceETH(), 3005 ether);

        ForcedPriceFeed(address(priceFeed2)).setRevertNext(); // Make priceFeed2 fail
        ForcedPriceFeed(address(priceFeed3)).setRevertNext(); // Make priceFeed3 fail

        // performUpkeep internally calls _getPriceBTC and _getPriceETH
        priceAggregator.performUpkeep();

		// getPriceBTC() and getPriceETH() should now fail
		vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

		vm.expectRevert( "Invalid WETH price" );
        priceAggregator.getPriceETH();
    }


    // A unit test that checks the performUpkeep function, confirming whether it updates the BTC and ETH prices correctly.
    function testPerformUpkeep() public {
    	TestPriceAggregator tpa = new TestPriceAggregator();

        // Check BTC price updates
        uint256 feed1BTCPrice = priceFeed1.getPriceBTC();
        uint256 feed2BTCPrice = priceFeed2.getPriceBTC();
        uint256 feed3BTCPrice = priceFeed3.getPriceBTC();
        uint256 aggregatedBTCPrice = tpa.aggregatePrices(feed1BTCPrice, feed2BTCPrice, feed3BTCPrice);

        // Check ETH price updates
        uint256 feed1ETHPrice = priceFeed1.getPriceETH();
        uint256 feed2ETHPrice = priceFeed2.getPriceETH();
        uint256 feed3ETHPrice = priceFeed3.getPriceETH();
        uint256 aggregatedETHPrice = tpa.aggregatePrices(feed1ETHPrice, feed2ETHPrice, feed3ETHPrice);

		// Cached prices are zero and invalid before performUpkeep
		vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

		vm.expectRevert( "Invalid WETH price" );
        priceAggregator.getPriceETH();

        // Call performUpkeep
        priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), aggregatedBTCPrice );
		assertEq( priceAggregator.getPriceETH(), aggregatedETHPrice );
    }


    // A unit test that verifies the _aggregatePrices function could update the priceFeedInclusionAverage correctly by exponential average.
    function testAverageNumberValidFeeds() public {

        ForcedPriceFeed(address(priceFeed2)).setRevertNext(); // Make priceFeed2 fail

    	priceAggregator.performUpkeep();

		// Average should start out at 2
		assertEq( priceAggregator.averageNumberValidFeeds(), 2000000000000000000 );

        ForcedPriceFeed(address(priceFeed3)).setRevertNext(); // Make priceFeed3 fail

		for( uint256 i = 0; i < 400; i++ )
			{
	    	priceAggregator.performUpkeep();
			}
		assertEq( priceAggregator.averageNumberValidFeeds(), 1201573311186041581 );


		// Trend towards 3
        ForcedPriceFeed(address(priceFeed2)).clearRevertNext();
        ForcedPriceFeed(address(priceFeed3)).clearRevertNext();
		for( uint256 i = 0; i < 500; i++ )
			{
	    	priceAggregator.performUpkeep();
			}
		assertEq( priceAggregator.averageNumberValidFeeds(), 2757096358119972024 );
    }


    // A unit test to verify the _aggregatePrices function should return zero when the number of valid prices is one or less
    function testAggregatePricesWhenValidCountIsLessOrEqualOne() public {

        ForcedPriceFeed(address(priceFeed2)).setRevertNext();
        ForcedPriceFeed(address(priceFeed3)).setRevertNext();

        // Execute _aggregatePrices with external call
        priceAggregator.performUpkeep();

        // Expected revert when getting BTC Price
        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();

        // Test a case where no feed has valid price
        ForcedPriceFeed(address(priceFeed1)).setRevertNext();

        // Execute _aggregatePrices with external call
        priceAggregator.performUpkeep();

        // Expected revert when getting BTC Price
        vm.expectRevert( "Invalid WBTC price" );
        priceAggregator.getPriceBTC();
    }


    // A unit test that verifies the performUpkeep function works even if the price feeds return zero.
    function testPerformUpKeep() public
    {
        ForcedPriceFeed(address(priceFeed1)).setRevertNext();
        ForcedPriceFeed(address(priceFeed2)).setRevertNext();
        ForcedPriceFeed(address(priceFeed3)).setRevertNext();

        // Test performUpkeep when all price feeds return zero
        priceAggregator.performUpkeep();

        // Asserting that it returns zero.
        vm.expectRevert("Invalid WBTC price");
        priceAggregator.getPriceBTC();

        vm.expectRevert("Invalid WETH price");
        priceAggregator.getPriceETH();

        // Asserting inclusion average (should be 0 as no feed returned non-zero price)
        assertEq(priceAggregator.averageNumberValidFeeds(), 0);
    }

	}



