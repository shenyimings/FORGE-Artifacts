// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../interfaces/IExchangeConfig.sol";
import "../pools/PoolUtils.sol";


// Finds a circular path after a user's swap has occurred (from WETH to WETH in this case) that results in an arbitrage profit.
contract ArbitrageSearch
    {
	IERC20 immutable public wbtc;
	IERC20 immutable public weth;
	ISalt immutable public salt;

	// Used to estimate the point just to the right of the midpoint
   	uint256 constant public MIDPOINT_PRECISION = 10**15; // .001 ETH precision for arb search


    constructor( IExchangeConfig _exchangeConfig )
    	{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		// Cached for efficiency
		wbtc = _exchangeConfig.wbtc();
		weth = _exchangeConfig.weth();
		salt = _exchangeConfig.salt();
    	}


	// Returns the arbitrage path to use based on swapTokenIn and swapTokenOut - where those two tokens form a whitelisted pair and have direct liquidity in the pools.
	// Swaps are circular and will start and end with WETH.
	// Returned cycle is: weth->arbToken2->arbToken3->weth
	function _directArbitragePath( IERC20 swapTokenIn, IERC20 swapTokenOut ) internal view returns (IERC20 arbToken2, IERC20 arbToken3)
		{
		// swap: WBTC->WETH
        // arb: WETH->WBTC->SALT->WETH
		if ( address(swapTokenIn) == address(wbtc))
		if ( address(swapTokenOut) == address(weth))
			return (wbtc, salt);

		// swap: WETH->WBTC
        // arb: WETH->SALT->WBTC->WETH
		if ( address(swapTokenIn) == address(weth))
		if ( address(swapTokenOut) == address(wbtc))
			return (salt, wbtc);

		// swap: WETH->token
        // arb: WETH->WBTC->token->WETH
		if ( address(swapTokenIn) == address(weth))
			return (wbtc, swapTokenOut);

		// swap: token->WETH
        // arb: WETH->token->WBTC->WETH
		if ( address(swapTokenOut) == address(weth))
			return (swapTokenIn, wbtc);

		// swap: token1->token2
        // arb: WETH->token2->token1->WETH
		return (swapTokenOut, swapTokenIn);
		}


	// Returns the arbitrage path to use based on swapTokenIn and swapTokenOut - where those two tokens don't form a whitelisted pair
	// Swaps are circular and will start and end with WETH.
	function _indirectArbitragePath( IERC20 swapTokenIn, IERC20 swapTokenOut ) internal pure returns (IERC20 arbToken2, IERC20 arbToken3)
		{
		// swap: swapTokenIn->WETH->swapTokenOut   (intermediate WETH used in swaps without direct pool on exchange)
		// arb: WETH->arbToken2->WBTC->arbToken3->WETH
		return (swapTokenIn, swapTokenOut);
		}


	// Given the reserves for the arbitrage swap, calculate the profit at the midpoint of the current possible range and just to the right of the midpoint.
	function _determineProfits( uint256 midpoint, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1, uint256 reservesD0, uint256 reservesD1 ) internal pure returns (int256 profitMidpoint, int256 profitRightOfMidpoint )
		{
		uint256 kA = reservesA0 * reservesA1;
		uint256 kB = reservesB0 * reservesB1;
		uint256 kC = reservesC0 * reservesC1;

		// Estimate the AMM output of the midpoint
		uint256 amountOut = reservesA1 - kA / ( reservesA0 + midpoint );
		amountOut = reservesB1 - kB / ( reservesB0 + amountOut );
		amountOut = reservesC1 - kC / ( reservesC0 + amountOut );
		if ( reservesD0 > PoolUtils.DUST )
			amountOut = reservesD1 - ( reservesD0 * reservesD1 ) / ( reservesD0 + amountOut );

		profitMidpoint = int256(amountOut) - int256(midpoint);

		// Estimate the AMM output of a point just to the right of the midpoint
		amountOut = reservesA1 - kA / ( reservesA0 + (midpoint + MIDPOINT_PRECISION) );
		amountOut = reservesB1 - kB / ( reservesB0 + amountOut );
		amountOut = reservesC1 - kC / ( reservesC0 + amountOut );
		if ( reservesD0 > PoolUtils.DUST )
			amountOut = reservesD1 - ( reservesD0 * reservesD1 ) / ( reservesD0 + amountOut );

		profitRightOfMidpoint = int256(amountOut) - int256(midpoint + MIDPOINT_PRECISION);
		}


	// Perform a modified binary search to search for the bestArbAmountIn in a range of 1% to 125% of swapAmountInValueInETH.
	// The search will be done using a binary search algorithm where profits are determined at the midpoint of the current range, and also just to the right of the midpoint.
	// Assuming that the profit function is unimodal (which may not actually be true), the two profit calculations at and near the midpoint can show us which half of the range the maximum profit is in.
	function _binarySearch( uint256 swapAmountInValueInETH, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1, uint256 reservesD0, uint256 reservesD1 ) internal pure returns (uint256 bestArbAmountIn)
		{
		if ( reservesA0 <= PoolUtils.DUST || reservesA1 <= PoolUtils.DUST || reservesB0 <= PoolUtils.DUST || reservesB1 <= PoolUtils.DUST || reservesC0 <= PoolUtils.DUST || reservesC1 <= PoolUtils.DUST )
			return 0;

		// Search bestArbAmountIn in a range from 1% to 125% of swapAmountInValueInETH.
    	uint256 leftPoint = swapAmountInValueInETH / 100;
    	uint256 rightPoint = swapAmountInValueInETH + swapAmountInValueInETH >> 2; // 125% of swapAmountInValueInETH

		int256 profitMidpoint;
		int256 profitRightOfMidpoint;

		// Cost is about 2477 gas per loop iteration
		for( uint256 i = 0; i < 5; i++ )
			{
			(profitMidpoint, profitRightOfMidpoint) = _determineProfits( (leftPoint + rightPoint) >> 1, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1, reservesD0, reservesD1 );

			// If the midpoint isn't profitable then we can remove the right half the range as nothing there will be profitable either
			if ( profitMidpoint < int256(PoolUtils.DUST) )
				rightPoint = (leftPoint + rightPoint) >> 1;
			else
				{
				// See if this new profit is more than the previously calculated profit of the midpoint
				if ( profitRightOfMidpoint > profitMidpoint )
					{
					// Right side of the midpoint is more profitable and the profit curve is unimodal so remove the left half of the range
					leftPoint = (leftPoint + rightPoint) >> 1;
					}
				else
					{
					// Midpoint is more profitable and the profit curve is unimodal so remove the right half of the range
					rightPoint = (leftPoint + rightPoint) >> 1;
					}
				}
			}

		// Make sure the midpoint is actually profitable (taking into account precision errors)
		if ( profitMidpoint < int256(PoolUtils.DUST) )
			return 0;

		return (leftPoint + rightPoint) >> 1;
		}
	}

