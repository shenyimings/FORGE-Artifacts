// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


// Counterswaps allow the protocol to swap one given token for another in a way that doesn't impact the market directly.
// It is done by waiting for users to swap in the opposite direction and then swapping in the desired direction within the same transaction - essentially restoring the reserves to where they were before the user swap.
// This is done to gradually swap WETH to SALT and USDS for Protocol Owned Liquidity and liquidated WBTC and WETH collateral to USDS so that the USDS can be burned.
// Counterswaps are only performed when the price is favorable (for the counterswap) compared to a recent average.
// Counterswaps are deposited into the Pools contract and owned by the constant addresses below.

library Counterswap
	{
	// Counterswap addresses which own deposited tokens in the Pools contract
	address constant public WETH_TO_SALT = address(bytes20(uint160(uint256(keccak256('counterswap WETH to SALT')))));
	address constant public WETH_TO_USDS = address(bytes20(uint160(uint256(keccak256('counterswap WETH to USDS')))));
	address constant public WBTC_TO_USDS = address(bytes20(uint160(uint256(keccak256('counterswap WBTC to USDS')))));


	// Determine the counterswap address for swapping tokenToCounterswap -> desiredToken
	function _determineCounterswapAddress( IERC20 tokenToCounterswap, IERC20 desiredToken, IERC20 wbtc, IERC20 weth, IERC20 salt, IERC20 usds ) internal pure returns (address counterswapAddress)
		{
		if ( address(tokenToCounterswap) == address(weth) )
			{
			if ( address(desiredToken) == address(salt) )
				return WETH_TO_SALT;
			if ( address(desiredToken) == address(usds) )
				return WETH_TO_USDS;
			}

		if ( (address(tokenToCounterswap) == address(wbtc)) && (address(desiredToken) == address(usds)) )
			return WBTC_TO_USDS;

		return address(0);
		}
	}