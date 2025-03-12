// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../Pools.sol";


contract TestPools is Pools
    {
    constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig )
    Pools(_exchangeConfig, _poolsConfig)
    	{
    	}

	function isWhitelistedCache(bytes32 poolID) public view returns (bool)
		{
		return _isWhitelistedCache[poolID];
		}


	function shouldCounterswap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 swapAmountOut ) public view returns (bool)
		{
		address counterswapAddress = Counterswap._determineCounterswapAddress(swapTokenOut, swapTokenIn, wbtc, weth, salt, usds);

		return _shouldCounterswap(swapTokenIn, swapTokenOut, counterswapAddress, swapAmountIn, swapAmountOut );
		}
    }