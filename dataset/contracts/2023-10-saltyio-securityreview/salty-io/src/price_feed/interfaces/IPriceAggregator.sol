// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "./IPriceFeed.sol";


interface IPriceAggregator
	{
	function setInitialFeeds( IPriceFeed _priceFeed1, IPriceFeed _priceFeed2, IPriceFeed _priceFeed3 ) external;
	function setPriceFeed( uint256 priceFeedNum, IPriceFeed newPriceFeed ) external; // onlyOwner
	function changeMaximumPriceFeedPercentDifferenceTimes1000(bool increase) external; // onlyOwner
	function changeSetPriceFeedCooldown(bool increase) external; // onlyOwner

	// Views
	function maximumPriceFeedPercentDifferenceTimes1000() external view returns (uint256);
	function setPriceFeedCooldown() external view returns (uint256);
	function lastTimestampSetPriceFeed() external view returns (uint256);
	function averageNumberValidFeeds() external view returns (uint256);

	function priceFeed1() external view returns (IPriceFeed);
	function priceFeed2() external view returns (IPriceFeed);
	function priceFeed3() external view returns (IPriceFeed);
	function getPriceBTC() external view returns (uint256);
	function getPriceETH() external view returns (uint256);

	function performUpkeep() external;
	}
