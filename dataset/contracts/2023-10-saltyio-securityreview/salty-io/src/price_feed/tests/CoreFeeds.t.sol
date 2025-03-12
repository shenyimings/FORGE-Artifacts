// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";
import "../CoreChainlinkFeed.sol";
import "../CoreUniswapFeed.sol";
import "../CoreSaltyFeed.sol";


contract TestCoreFeeds is Deployment
	{
	IPriceFeed public chainlinkFeed;
	IPriceFeed public uniswapFeed;
	IPriceFeed public saltyFeed;

	address public alice = address(0x1111);


	constructor()
		{

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		finalizeBootstrap();

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);



		chainlinkFeed = new CoreChainlinkFeed( CHAINLINK_BTC_USD, CHAINLINK_ETH_USD );
		uniswapFeed = new CoreUniswapFeed( IERC20(_testBTC), IERC20(_testETH), IERC20(_testUSDC), UNISWAP_V3_BTC_ETH, UNISWAP_V3_USDC_ETH );
		saltyFeed = new CoreSaltyFeed( pools, exchangeConfig );
		}


	function testFeeds() public
		{
		console.log( "chainlink btc: ", chainlinkFeed.getPriceBTC() / 10**18 );
		console.log( "chainlink eth: ", chainlinkFeed.getPriceETH() / 10**18 );

		console.log( "uniswap btc: ", uniswapFeed.getPriceBTC() / 10**18 );
		console.log( "uniswap eth: ", uniswapFeed.getPriceETH() / 10**18 );

		vm.prank(address(collateral));
		usds.mintTo(DEPLOYER, 100000000 ether );

		vm.startPrank(DEPLOYER);
		usds.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );
		wbtc.approve( address(pools), type(uint256).max );

		pools.addLiquidity(weth, usds, 1000 ether, 1850000 ether, 0, block.timestamp );
		pools.addLiquidity(wbtc, usds, 100 * 10**8, 2919100 ether, 0, block.timestamp );

		vm.stopPrank();

		console.log( "salty btc: ", saltyFeed.getPriceBTC() / 10**18 );
		console.log( "salty eth: ", saltyFeed.getPriceETH() / 10**18 );
		}
	}