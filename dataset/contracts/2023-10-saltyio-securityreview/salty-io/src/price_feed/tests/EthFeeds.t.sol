// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../interfaces/IPriceFeed.sol";
import "../CoreChainlinkFeed.sol";
import "../CoreSaltyFeed.sol";
import "../CoreUniswapFeed.sol";
import "../../ExchangeConfig.sol";


contract TestEthFeeds is Test
	{
	IPriceFeed public chainlinkFeed;
	IPriceFeed public uniswapFeed;


	constructor()
		{
		if ( keccak256(bytes(vm.envString("NETWORK" ))) != keccak256(bytes("eth" )))
			return;

		// Live addresses on Ethereum
		address CHAINLINK_BTC_USD = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
		address CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
		address UNISWAP_V3_BTC_ETH = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
		address UNISWAP_V3_USDC_ETH = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

		address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
		address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
		address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

		chainlinkFeed = new CoreChainlinkFeed( CHAINLINK_BTC_USD, CHAINLINK_ETH_USD );
		uniswapFeed = new CoreUniswapFeed( IERC20(WBTC), IERC20(WETH), IERC20(USDC), UNISWAP_V3_BTC_ETH, UNISWAP_V3_USDC_ETH );
		}


	function testFeeds() public
		{
		if ( keccak256(bytes(vm.envString("NETWORK" ))) != keccak256(bytes("eth" )))
			return;

		console.log( "chainlink btc: ", chainlinkFeed.getPriceBTC() / 10**18 );
		console.log( "chainlink eth: ", chainlinkFeed.getPriceETH() / 10**18 );

		console.log( "uniswap btc: ", uniswapFeed.getPriceBTC() / 10**18 );
		console.log( "uniswap eth: ", uniswapFeed.getPriceETH() / 10**18 );

		// Check prices are similar
		int256 diff = int256(chainlinkFeed.getPriceBTC()) - int256(uniswapFeed.getPriceBTC());
		if ( diff < 0 )
			diff = -diff;

		assertTrue( (diff * 100 / int256(chainlinkFeed.getPriceBTC())) < 2, "BTC price difference too large" );

		diff = int256(chainlinkFeed.getPriceETH()) - int256(uniswapFeed.getPriceETH());
		if ( diff < 0 )
			diff = -diff;
		assertTrue( (diff * 100 / int256(chainlinkFeed.getPriceETH())) < 2, "ETH price difference too large" );
		}
	}



