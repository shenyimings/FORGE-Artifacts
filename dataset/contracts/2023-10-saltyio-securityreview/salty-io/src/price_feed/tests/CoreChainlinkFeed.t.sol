// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "./TestChainlinkAggregator.sol";
import "../interfaces/IPriceFeed.sol";
import "../CoreChainlinkFeed.sol";


contract TestCoreChainlinkFeed is Test
	{
	IPriceFeed public chainlinkFeed;

	TestChainlinkAggregator public btcAggregator;
	TestChainlinkAggregator public ethAggregator;


	constructor()
		{
		btcAggregator = new TestChainlinkAggregator( 29229 ether );
		ethAggregator = new TestChainlinkAggregator( 1861 ether );

		chainlinkFeed = new CoreChainlinkFeed( address(btcAggregator), address(ethAggregator) );
		}


	// A unit test that verifies the constructor function correctly sets the CHAINLINK_BTC_USD and CHAINLINK_ETH_USD addresses. Test for the case when valid addresses are passed as well as when one or both of the addresses are the zero address.
	function testConstructor() public
    {
    	// Prepare mock Chainlink aggregator addresses
    	TestChainlinkAggregator btcAggregator2 = new TestChainlinkAggregator(29229 ether);
    	TestChainlinkAggregator ethAggregator2 = new TestChainlinkAggregator(1861 ether);

    	// Test with valid addresses
    	CoreChainlinkFeed validFeed = new CoreChainlinkFeed(address(btcAggregator2), address(ethAggregator2));
    	assertEq(validFeed.CHAINLINK_BTC_USD(), address(btcAggregator2));
    	assertEq(validFeed.CHAINLINK_ETH_USD(), address(ethAggregator2));

    	// Test with one address being the zero address
    	vm.expectRevert("_CHAINLINK_BTC_USD cannot be address(0)");
    	new CoreChainlinkFeed(address(0), address(ethAggregator2));

    	vm.expectRevert("_CHAINLINK_ETH_USD cannot be address(0)");
    	new CoreChainlinkFeed(address(btcAggregator2), address(0));
    }


	// A unit test that verifies the latestChainlinkPrice function correctly converts the price from 8 decimals to 18 decimals and returns the expected result. This can be done by setting a known price in the TestChainlinkAggregator and checking that latestChainlinkPrice returns the expected value.
	function testLatestChainlinkPrice() public
    {
        // Set a known price in the btcAggregator
        btcAggregator.setPrice(29229 *10**8);  // price with 8 decimals
        uint256 expectedPrice = 29229 ether;  // price with 18 decimals

        // Call latestChainlinkPrice with the btcAggregator address and check the result
        uint256 resultPrice = chainlinkFeed.getPriceBTC();
        assertEq(resultPrice, expectedPrice);
    }


	// A unit test that verifies the latestChainlinkPrice function returns zero when the latestRoundData function call fails. This can be done by mocking a failure in the TestChainlinkAggregator and checking that latestChainlinkPrice returns zero.
	function testLatestChainlinkPriceWithFailure() public
    {
        btcAggregator.setShouldFail();

        // Call latestChainlinkPrice with the btcAggregator address and check that it returns 0
        uint256 resultPrice = chainlinkFeed.getPriceBTC();
        assertEq(resultPrice, 0);
    }


	// A unit test that verifies the getPriceBTC and getPriceETH functions correctly retrieve and return the price of BTC and ETH from the Chainlink oracle, respectively. This can be done by setting a known price in the btcAggregator and ethAggregator and checking that getPriceBTC and getPriceETH return the expected value.
	function testGetPriceBTCandETH() public
    {
        // Set known prices in the btcAggregator and ethAggregator
        uint256 knownBtcPrice = 1 ether;
        uint256 knownEthPrice = 2 ether;

        btcAggregator.setPrice(knownBtcPrice);
        ethAggregator.setPrice(knownEthPrice);

        // Call getPriceBTC and getPriceETH and check that they return the expected values
        uint256 returnedBtcPrice = chainlinkFeed.getPriceBTC();
        uint256 returnedEthPrice = chainlinkFeed.getPriceETH();

        assertEq(returnedBtcPrice, knownBtcPrice * 10**10);
        assertEq(returnedEthPrice, knownEthPrice * 10**10);
    }


	// A unit test that simulates the scenario where the Chainlink oracle suddenly changes the price. You could test the situation where the price significantly increases or decreases between two calls to the getPriceBTC or getPriceETH functions, and verify that the contract correctly reflects these changes.
	function testChangePrices() public
    {
        // Set known prices in the btcAggregator and ethAggregator
        uint256 knownBtcPrice = 1 ether;
        uint256 knownEthPrice = 2 ether;

        btcAggregator.setPrice(knownBtcPrice);
        ethAggregator.setPrice(knownEthPrice);

        // Call getPriceBTC and getPriceETH and check that they return the expected values
        uint256 returnedBtcPrice = chainlinkFeed.getPriceBTC();
        uint256 returnedEthPrice = chainlinkFeed.getPriceETH();

        assertEq(returnedBtcPrice, knownBtcPrice * 10**10);
        assertEq(returnedEthPrice, knownEthPrice * 10**10);

		// Change prices
        btcAggregator.setPrice(knownBtcPrice * 5);
        ethAggregator.setPrice(knownEthPrice / 5);

		// And test
        returnedBtcPrice = chainlinkFeed.getPriceBTC();
        returnedEthPrice = chainlinkFeed.getPriceETH();

        assertEq(returnedBtcPrice, knownBtcPrice * 10**10 * 5 );
        assertEq(returnedEthPrice, knownEthPrice * 10**10 / 5);
    }
	}



