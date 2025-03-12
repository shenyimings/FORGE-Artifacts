pragma solidity 0.4.26;

import "./interfaces/IConsumerPriceOracle.sol";

/**
 * @dev Provides the trivial ETH/ETH rate to be used with other TKN/ETH rates
 */
contract MocBTCToBTCOracle is IConsumerPriceOracle {
	int256 private constant BTC_RATE = 1;

	/**
	 * @dev returns the trivial ETH/ETH rate.
	 *
	 * @return always returns the trivial rate of 1
	 */
	function latestAnswer() external view returns (int256) {
		return BTC_RATE;
	}

	/**
	 * @dev returns the trivial ETH/ETH update time.
	 *
	 * @return always returns current block's timestamp
	 */
	function latestTimestamp() external view returns (uint256) {
		return now;
	}
}
