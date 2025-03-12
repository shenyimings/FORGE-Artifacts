// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./IForcedPriceFeed.sol";


// For testing liquidation which requires that collteral has insufficient value to proceed
contract ForcedPriceFeed is IForcedPriceFeed, Ownable
    {
    bool public revertNext;

	uint256 public forcedPriceBTCWith18Decimals;
	uint256 public forcedPriceETHWith18Decimals;


	constructor( uint256 _forcedPriceBTCWith18Decimals, uint256 _forcedPriceETHWith18Decimals )
		{
		forcedPriceBTCWith18Decimals = _forcedPriceBTCWith18Decimals;
		forcedPriceETHWith18Decimals = _forcedPriceETHWith18Decimals;
		}


	function setBTCPrice( uint256 _forcedPriceBTCWith18Decimals ) public onlyOwner
		{
		forcedPriceBTCWith18Decimals = _forcedPriceBTCWith18Decimals;
		}


	function setETHPrice( uint256 _forcedPriceETHWith18Decimals ) public onlyOwner
		{
		forcedPriceETHWith18Decimals = _forcedPriceETHWith18Decimals;
		}


	function setRevertNext() public
		{
		revertNext = true;
		}


	function clearRevertNext() public
		{
		revertNext = false;
		}


	function getPriceBTC() external view returns (uint256)
		{
		require( !revertNext, "revertNext is true" );

		return forcedPriceBTCWith18Decimals;
		}


	function getPriceETH() external view returns (uint256)
		{
		require( !revertNext, "revertNext is true" );

		return forcedPriceETHWith18Decimals;
		}
    }