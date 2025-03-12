pragma solidity 0.4.26;

import "./interfaces/IConsumerPriceOracle.sol";

/**
 * @dev Provides the BTC/USD rate
 */
contract ChainlinkBTCToUSDOracle is IConsumerPriceOracle {
	int256 private constant BTC_RATE = 10000;

	/**
	 * @dev returns the BTC/USD rate.
	 *
	 * @return always returns the rate of 1
	 */
	function latestAnswer() external view returns (int256) {
		return BTC_RATE;
	}

	/**
	 * @dev returns the BTC/USD update time.
	 *
	 * @return always returns current block's timestamp
	 */
	function latestTimestamp() external view returns (uint256) {
		return now;
	}
}
