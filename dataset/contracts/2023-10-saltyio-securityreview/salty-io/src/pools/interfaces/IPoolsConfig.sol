// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./IPools.sol";


interface IPoolsConfig
	{
	function whitelistPool( IPools pools, IERC20 tokenA, IERC20 tokenB ) external; // onlyOwner
	function unwhitelistPool( IPools pools, IERC20 tokenA, IERC20 tokenB ) external; // onlyOwner
	function changeMaximumWhitelistedPools(bool increase) external; // onlyOwner

	// Views
    function maximumWhitelistedPools() external view returns (uint256);

	function numberOfWhitelistedPools() external view returns (uint256);
	function whitelistedPoolAtIndex( uint256 index ) external view returns (bytes32);
	function isWhitelisted( bytes32 poolID ) external view returns (bool);
	function whitelistedPools() external view returns (bytes32[] calldata);
	function underlyingTokenPair( bytes32 poolID ) external view returns (IERC20 tokenA, IERC20 tokenB);
	function tokenHasBeenWhitelisted( IERC20 token, IERC20 wbtc, IERC20 weth ) external view returns (bool);
	}