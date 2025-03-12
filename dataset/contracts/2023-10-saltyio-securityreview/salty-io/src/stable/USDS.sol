// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../stable/interfaces/ICollateral.sol";
import "./interfaces/IUSDS.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/Counterswap.sol";
import "../interfaces/IExchangeConfig.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";


// USDS can be borrowed by users who have deposited WBTC/WETH liquidity as collateral via Collateral.sol
// The default initial collateralization ratio of collateral / borrowed USDS is 200%.
// The minimum default collateral ratio is 110% - below which positions can be liquidated by any user.

// If WBTC/WETH collateral is liquidated the reclaimed WBTC and WETH tokens are sent to this contract and swapped for USDS (via counterswapping) which is then burned (essentially "undoing" the user's original collateral deposit and USDS borrow).
contract USDS is ERC20, IUSDS, Ownable
    {
    IERC20 immutable public wbtc;
    IERC20 immutable public weth;

    ICollateral public collateral;
    IPools public pools;
    IExchangeConfig public exchangeConfig;

	// This corresponds to USDS that was borrowed by users who had their collateral liquidated.
	// Because liquidated collateral no longer exists the borrowed USDS needs to be burned as well in order to
	// "undo" the collateralized position and return state back to where it was before the liquidated user deposited collateral and borrowed USDS.
	uint256 public usdsThatShouldBeBurned;


	constructor( IERC20 _wbtc, IERC20 _weth )
	ERC20( "testUSDS", "USDS" )
		{
		require( address(_wbtc) != address(0), "_wbtc cannot be address(0)" );
		require( address(_weth) != address(0), "_weth cannot be address(0)" );

		wbtc = _wbtc;
		weth = _weth;
        }


	// These contracts will be set at deployment time and after that become immutable
	function setContracts( ICollateral _collateral, IPools _pools, IExchangeConfig _exchangeConfig ) public onlyOwner
		{
		require( address(_collateral) != address(0), "_collateral cannot be address(0)" );
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		collateral = _collateral;
		pools = _pools;
		exchangeConfig = _exchangeConfig;

		// setContracts can only be called once
		renounceOwnership();
		}


	// Mint from the Collateral contract to allow users to borrow USDS after depositing BTC/ETH liquidity as collateral.
	// Only callable by the Collateral contract.
	function mintTo( address wallet, uint256 amount ) public
		{
		require( msg.sender == address(collateral), "USDS.mintTo is only callable from the Collateral contract" );
		require( address(wallet) != address(0), "Cannot mint to address(0)" );
		require( amount > 0, "Cannot mint zero USDS" );

		_mint( wallet, amount );
		}


	// Called when a user's collateral position has been liquidated to indicate that the borrowed USDS from that position needs to be burned.
	function shouldBurnMoreUSDS( uint256 usdsToBurn ) public
		{
		require( msg.sender == address(collateral), "USDS.shouldBurnMoreUSDS is only callable from the Collateral contract" );

		usdsThatShouldBeBurned += usdsToBurn;
		}


	// Send the full balance of the specified token to the Counterswap contract so that it will be gradually converted to USDS (when users swap first in the opposite direction)
	function _sendTokenToCounterswap( IERC20 token, address counterswapAddress ) internal
		{
		uint256 tokenBalance = token.balanceOf( address(this) );
		if ( tokenBalance == 0 )
			return;

		token.approve( address(pools), tokenBalance );

		// Deposit the token in the Pools contract for the specified counterswapAddress so that the proper counterswap will be made as users swap in the opposite direction.
		pools.depositTokenForCounterswap( counterswapAddress, token, tokenBalance );
		}


	function _withdrawUSDSFromCounterswap( address counterswapAddress, uint256 remainingUSDSToBurn ) internal returns (uint256)
		{
		// Determine how much USDS has previously been converted through the specified counterswap and should be withdrawn from the Pools contract.
		uint256 usdsToWithdraw = pools.depositedBalance( counterswapAddress, this );

		// Don't withdraw more USDS than remainingUSDSToBurn
		if ( usdsToWithdraw > remainingUSDSToBurn )
			usdsToWithdraw = remainingUSDSToBurn;

		if ( usdsToWithdraw == 0 )
			return remainingUSDSToBurn;

		// Withdraw USDS (this ERC20 contract) from Counterswap
		pools.withdrawTokenFromCounterswap( counterswapAddress, this, usdsToWithdraw );

		return remainingUSDSToBurn - usdsToWithdraw;
		}


	// Deposit all WBTC and WETH in this contract to the Pools contract under the correct counterswap addresses so that the tokens can gradually be swapped to USDS (which can then be burned).
	// Also, withdraw and burn USDS which has already been obtained through previous counterswaps.
	function performUpkeep() public
		{
		require( msg.sender == address(exchangeConfig.upkeep()), "USDS.performUpkeep is only callable from the Upkeep contract" );

		// Send any WBTC or WETH in this contract to the Counterswap contract for gradual conversion to USDS
		_sendTokenToCounterswap(wbtc, Counterswap.WBTC_TO_USDS);
		_sendTokenToCounterswap(weth, Counterswap.WETH_TO_USDS);

		if ( usdsThatShouldBeBurned == 0 )
			return;

		// Everything in the contract will be burned up to the specified amount
		uint256 startingBalance = balanceOf(address(this));

		if ( startingBalance > usdsThatShouldBeBurned )
			{
			// Only part of the startingBalance will be burned
			_burn( address(this), usdsThatShouldBeBurned );
    		usdsThatShouldBeBurned = 0;

			return;
			}
		else
			{
			// The entire startingBalance will be burned
			usdsThatShouldBeBurned -= startingBalance;
			}


		// Withdraw up to usdsThatShouldBeBurned from previously done WBTC->USDS and WETH->USDS counterswaps
		uint256 tempRemainingToBurn = _withdrawUSDSFromCounterswap( Counterswap.WBTC_TO_USDS, usdsThatShouldBeBurned );
		usdsThatShouldBeBurned = _withdrawUSDSFromCounterswap( Counterswap.WETH_TO_USDS, tempRemainingToBurn );

		// Burn all the USDS that was just withdrawn (and any other USDS in the contract).
		// Extra USDS will remain in counterswap as a buffer of burnable USDS in case any liquidated collateral positions are ever underwater.
		_burn( address(this), balanceOf(address(this)) );
		}
	}

