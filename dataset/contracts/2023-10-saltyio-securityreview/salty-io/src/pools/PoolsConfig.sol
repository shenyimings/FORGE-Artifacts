// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IPoolsConfig.sol";
import "./PoolUtils.sol";


// Contract owned by the DAO and only modifiable by the DAO
contract PoolsConfig is IPoolsConfig, Ownable
    {
	struct TokenPair
		{
		// Note that these will be ordered as specified in whitelistPool() - rather than ordered such that address(tokenA) < address(tokenB) as with the reserves in Pools.sol
		IERC20 tokenA;
		IERC20 tokenB;
		}

    using EnumerableSet for EnumerableSet.Bytes32Set;


	// Keeps track of what pools have been whitelisted
	EnumerableSet.Bytes32Set private _whitelist;

	// A mapping from poolIDs to the underlying TokenPair
	mapping(bytes32=>TokenPair) public underlyingPoolTokens;

	// The maximum number of pools that can be whitelisted at any one time.
	// If the maximum number of pools is reached, some tokens will need to be delisted before new ones can be whitelisted
	// Range: 20 to 100 with an adjustment of 10
	uint256 public maximumWhitelistedPools = 50;


	// Whitelist a given pair of tokens
	function whitelistPool( IPools pools, IERC20 tokenA, IERC20 tokenB ) public onlyOwner
		{
		require( _whitelist.length() < maximumWhitelistedPools, "Maximum number of whitelisted pools already reached" );
		require(tokenA != tokenB, "tokenA and tokenB cannot be the same token");

		(bytes32 poolID, ) = PoolUtils._poolID(tokenA, tokenB);

		underlyingPoolTokens[poolID] = TokenPair(tokenA, tokenB);

		if ( _whitelist.add(poolID) )
			pools.setIsWhitelisted(poolID);
		}


	function unwhitelistPool( IPools pools, IERC20 tokenA, IERC20 tokenB ) public onlyOwner
		{
		(bytes32 poolID, ) = PoolUtils._poolID(tokenA,tokenB);

		if ( _whitelist.remove(poolID) )
			pools.clearIsWhitelisted(poolID);
		}


	function changeMaximumWhitelistedPools(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (maximumWhitelistedPools < 100)
                maximumWhitelistedPools += 10;
            }
        else
            {
            if (maximumWhitelistedPools > 20)
                maximumWhitelistedPools -= 10;
            }
        }


	// === VIEWS ===

	function numberOfWhitelistedPools() public view returns (uint256)
		{
		return _whitelist.length();
		}


	// Return the poolID at the given index
	function whitelistedPoolAtIndex( uint256 index ) public view returns (bytes32)
		{
		return _whitelist.at( index );
		}


	function isWhitelisted( bytes32 poolID ) public view returns (bool)
		{
		if ( poolID == PoolUtils.STAKED_SALT )
			return true;

		return _whitelist.contains( poolID );
		}


	// Return an array of the currently whitelisted poolIDs
	function whitelistedPools() public view returns (bytes32[] memory)
		{
		return _whitelist.values();
		}


	function underlyingTokenPair( bytes32 poolID ) public view returns (IERC20 tokenA, IERC20 tokenB)
		{
		TokenPair memory pair = underlyingPoolTokens[poolID];
		require(address(pair.tokenA) != address(0) && address(pair.tokenB) != address(0), "This poolID does not exist");

		return (pair.tokenA, pair.tokenB);
		}


	// Returns true if the token has been whitelisted (meaning it has been pooled with either WBTC and WETH)
	function tokenHasBeenWhitelisted( IERC20 token, IERC20 wbtc, IERC20 weth ) public view returns (bool)
		{
		// See if the token has been whitelisted with either WBTC or WETH, as all whitelisted tokens are pooled with both WBTC and WETH
		(bytes32 poolID1,) = PoolUtils._poolID( token, wbtc );
		(bytes32 poolID2,) = PoolUtils._poolID( token, weth );

		if ( isWhitelisted(poolID1) || isWhitelisted(poolID2) )
			return true;

		return false;
		}
	}