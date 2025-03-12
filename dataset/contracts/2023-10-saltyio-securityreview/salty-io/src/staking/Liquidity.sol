// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStakingConfig.sol";
import "./StakingRewards.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/ILiquidity.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../pools/PoolUtils.sol";


// Allows users to add liquidity and increase their liquidity share in the  StakingRewards pool so that they can receive proportional future rewards.
contract Liquidity is ILiquidity, StakingRewards
    {
	using SafeERC20 for IERC20;

	IPools immutable public pools;


	constructor( IPools _pools, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig )
		StakingRewards( _exchangeConfig, _poolsConfig, _stakingConfig )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );

		pools = _pools;
		}


	// Add a certain amount of liquidity to the specified pool and increase the user's liqudiity share for that pool so that they can receive future rewards.
	// Tokens are zapped in by default - where all the tokens specified by the user are added to the liqudiity pool regardless of their ratio.
	// With zapping, if one of the tokens has excess in regards to the reserves token ratio, then some of it is first swapped for the other before the liquidity is added. (See PoolMath.sol for details)
	// bypassZapping allows this zapping to be avoided - which results in a simple addLiquidity call.
	// Requires exchange access for the sending wallet
	function addLiquidityAndIncreaseShare( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minLiquidityReceived, uint256 deadline, bool bypassZapping ) public nonReentrant returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity)
		{
		require( exchangeConfig.walletHasAccess(msg.sender), "Sender does not have exchange access" );

		// Remember the initial underlying token balances of this contract so we can later determine if any of the user's tokens are later unused for adding liquidity and should be sent back.
		uint256 startingBalanceA = tokenA.balanceOf( address(this) );
		uint256 startingBalanceB = tokenB.balanceOf( address(this) );

		// Transfer the specified maximum amount of tokens from the user
		tokenA.safeTransferFrom(msg.sender, address(this), maxAmountA );
		tokenB.safeTransferFrom(msg.sender, address(this), maxAmountB );

		// Zap in the specified liquidity (passing the specified bypassZapping as well).
		// The added liquidity will be owned by this contract. (external call)
		tokenA.approve( address(pools), maxAmountA );
		tokenB.approve( address(pools), maxAmountB );
		(addedAmountA, addedAmountB, addedLiquidity) = pools.dualZapInLiquidity( tokenA, tokenB, maxAmountA, maxAmountB, minLiquidityReceived, deadline, bypassZapping );

		// Avoid stack too deep
			{
			(bytes32 poolID,) = PoolUtils._poolID( tokenA, tokenB );

			// Increase the user's liquidity share by the amount of addedLiquidity.
			// Cooldown is specified to prevent reward hunting (ie - quickly depositing and withdrawing large amounts of liquidity to snipe rewards)
			// Here the pool will be confirmed as whitelisted as well.
			_increaseUserShare( msg.sender, poolID, addedLiquidity, true );
			}

		// If any of the user's tokens were not used for in the dualZapInLiquidity, then send them back
		uint256 unusedTokensA = tokenA.balanceOf( address(this) ) - startingBalanceA;
		if ( unusedTokensA > 0 )
			tokenA.safeTransfer( msg.sender, unusedTokensA );

		uint256 unusedTokensB = tokenB.balanceOf( address(this) ) - startingBalanceB;
		if ( unusedTokensB > 0 )
			tokenB.safeTransfer( msg.sender, unusedTokensB );
		}


	// Withdraw specified liquidity, decrease the user's liquidity share and claim any pending rewards.
	// The DAO itself is not allowed to withdraw liquidity
     function withdrawLiquidityAndClaim( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToWithdraw, uint256 minReclaimedA, uint256 minReclaimedB, uint256 deadline ) public nonReentrant returns (uint256 reclaimedA, uint256 reclaimedB)
		{
		// Make sure that the DAO isn't trying to remove liquidity
		require( msg.sender != address(exchangeConfig.dao()), "DAO is not allowed to withdraw liquidity" );

		(bytes32 poolID,) = PoolUtils._poolID( tokenA, tokenB );

		// Reduce the user's liqudiity share for the specified pool so that they receive less rewards.
		// Cooldown is specified to prevent reward hunting (ie - quickly depositing and withdrawing large amounts of liquidity to snipe rewards)
		// This call will send any pending SALT rewards to msg.sender as well.
		// Note: _decreaseUserShare checks to make sure that the user has the specified liquidity share.
		_decreaseUserShare( msg.sender, poolID, liquidityToWithdraw, true );

		// Remove the amount of liquidity specified by the user.
		// The liquidity in the pool is currently owned by this contract. (external call)
		(reclaimedA, reclaimedB) = pools.removeLiquidity( tokenA, tokenB, liquidityToWithdraw, minReclaimedA, minReclaimedB, deadline );

		// Transfer the reclaimed tokens to the user
		tokenA.safeTransfer( msg.sender, reclaimedA );
		tokenB.safeTransfer( msg.sender, reclaimedB );
		}
	}