// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface IForcedPriceFeed
	{
	function setRevertNext() external;
	function setBTCPrice( uint256 _forcedPriceBTCWith18Decimals ) external;
	function setETHPrice( uint256 _forcedPriceETHWith18Decimals ) external;
	function getPriceBTC() external view returns (uint256);
	function getPriceETH() external view returns (uint256);
	}
