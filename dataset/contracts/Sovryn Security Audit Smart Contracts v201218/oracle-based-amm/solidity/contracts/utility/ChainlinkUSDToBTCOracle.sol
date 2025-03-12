pragma solidity 0.4.26;

import "./interfaces/IConsumerPriceOracle.sol";

/**
 * @dev Provides the USD/BTC rate
 */
contract ChainlinkUSDToBTCOracle is IConsumerPriceOracle {
	int256 private constant USD_RATE = 10000;

	/**
	 * @dev returns the USD/BTC rate.
	 *
	 * @return always returns the rate of 10000
	 */
	function latestAnswer() external view returns (int256) {
		return USD_RATE;
	}

	/**
	 * @dev returns the USD/BTC update time.
	 *
	 * @return always returns current block's timestamp
	 */
	function latestTimestamp() external view returns (uint256) {
		return now;
	}
}
