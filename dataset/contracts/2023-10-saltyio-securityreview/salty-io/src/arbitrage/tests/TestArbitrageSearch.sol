// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../interfaces/IExchangeConfig.sol";
import "../../pools/PoolUtils.sol";
import "../ArbitrageSearch.sol";


contract TestArbitrageSearch is ArbitrageSearch
    {
    constructor( IExchangeConfig _exchangeConfig )
    ArbitrageSearch(_exchangeConfig)
    	{
    	}


	// Given the reserves for the arbitrage swap, calculate the profit at the midpoint of the current possible range and just to the right of the midpoint.
	function determineProfits( uint256 midpoint, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1, uint256 reservesD0, uint256 reservesD1 ) public pure returns (int256 profitMidpoint, int256 profitRightOfMidpoint )
		{
		return _determineProfits(midpoint, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1, reservesD0, reservesD1 );
		}


	// Perform a modified binary search to search for the bestArbAmountIn in a range of 1% to 125% of swapAmountInValueInETH.
	// The search will be done using a binary search algorithm where profits are determined at the midpoint of the current range, and also just to the right of the midpoint.
	// Assuming that the profit function is unimodal (which may not actually be true), the two profit calculations at and near the midpoint can show us which half of the range the maximum profit is in.
	function binarySearch( uint256 swapAmountInValueInETH, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1, uint256 reservesD0, uint256 reservesD1 ) public pure returns (uint256 bestArbAmountIn)
		{
		return _binarySearch( swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1, reservesD0, reservesD1 );
		}
	}

