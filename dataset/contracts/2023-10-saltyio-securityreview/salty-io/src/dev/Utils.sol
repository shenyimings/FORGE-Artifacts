// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";


// Convenience functions called from the Web3 UI
contract Utils
    {
	function tokenNames( address[] memory tokens ) public view returns (string[] memory)
		{
		string[] memory names = new string[]( tokens.length );

		for( uint256 i = 0; i < tokens.length; i++ )
			{
			ERC20 token = ERC20( tokens[i] );

			names[i] = token.symbol();
			}

		return names;
		}


	function tokenDecimals( address[] memory tokens ) public view returns (uint256[] memory)
		{
		uint256[] memory decimals = new uint256[]( tokens.length );

		uint256 index;
		for( uint256 i = 0; i < tokens.length; i++ )
			{
			ERC20 token = ERC20( tokens[i] );

			decimals[ index++ ] = token.decimals();
			}

		return decimals;
		}


	function tokenSupplies( address[] memory tokens ) public view returns (uint256[] memory)
		{
		uint256[] memory supplies = new uint256[]( tokens.length );

		uint256 index;
		for( uint256 i = 0; i < tokens.length; i++ )
			{
			IERC20 pair = IERC20( tokens[i] );

			supplies[ index++ ] = pair.totalSupply();
			}

		return supplies;
		}


	function underlyingTokens( IPoolsConfig poolsConfig, bytes32[] memory poolIDs ) public view returns (address[] memory)
		{
		address[] memory tokens = new address[]( poolIDs.length * 2 );

		uint256 index;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			(IERC20 token0, IERC20 token1) = poolsConfig.underlyingTokenPair( poolIDs[i] );

			tokens[ index++ ] = address(token0);
			tokens[ index++ ] = address(token1);
			}

		return tokens;
		}


	function poolReserves( IPools pools, IPoolsConfig poolsConfig, bytes32[] memory poolIDs ) public view returns (uint256[] memory)
		{
		uint256[] memory reserves = new uint256[]( poolIDs.length * 2 );

		uint256 index;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			(IERC20 token0, IERC20 token1) = poolsConfig.underlyingTokenPair( poolIDs[i] );
			(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves( token0, token1 );

			reserves[ index++ ] = reserve0;
			reserves[ index++ ] = reserve1;
			}

		return reserves;
		}



	function userBalances( address wallet, address[] memory tokenIDs ) public view  returns (uint256[] memory)
		{
		uint256[] memory balances = new uint256[]( tokenIDs.length );

		for( uint256 i = 0; i < tokenIDs.length; i++ )
			{
			IERC20 token = IERC20( tokenIDs[i] );

			balances[i] = token.balanceOf( wallet );
			}

		return balances;
		}
	}

