pragma solidity 0.4.26;

import "./interfaces/IConsumerPriceOracle.sol";
import "./Owned.sol";

interface Medianizer {
	function peek() external view returns (bytes32, bool);
}

contract MocBTCToUSDOracle is IConsumerPriceOracle, Owned {
	address public mocOracleAddress;

	event SetMoCOracleAddress(address indexed mocOracleAddress, address changerAddress);

	/**
	 * @dev initializes a ne MoC oracle
	 *
	 * @param _mocOracleAddress MoC oracle address
	 */
	constructor(address _mocOracleAddress) public {
		setMoCOracleAddress(_mocOracleAddress);
	}

	/**
	 * @dev returns the USD/BTC rate.
	 *
	 * @return MoC medianizer rate
	 */
	function latestAnswer() external view returns (int256) {
		(bytes32 value, bool hasValue) = Medianizer(mocOracleAddress).peek();
		require(hasValue, "Doesn't has value");
		return int256(value);
	}

	/**
	 * @dev returns the USD/BTC update time.
	 *
	 * @return always returns current block's timestamp
	 */
	function latestTimestamp() external view returns (uint256) {
		return now; // MoC oracle doesn't return update timestamp
	}

	/**
	 * @dev set MoC oracle address
	 *
	 * @param _mocOracleAddress MoC oracle address
	 */
	function setMoCOracleAddress(address _mocOracleAddress) public ownerOnly {
		require(_mocOracleAddress != address(0), "_mocOracleAddress shall not be zero address");
		mocOracleAddress = _mocOracleAddress;
		emit SetMoCOracleAddress(mocOracleAddress, msg.sender);
	}
}
