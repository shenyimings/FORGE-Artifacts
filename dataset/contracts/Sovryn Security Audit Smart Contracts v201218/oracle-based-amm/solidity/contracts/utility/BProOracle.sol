pragma solidity 0.4.26;

import "./interfaces/IMoCState.sol";
import "./interfaces/IConsumerPriceOracle.sol";
import "./Owned.sol";

contract BProOracle is IConsumerPriceOracle, Owned {
	address public mocStateAddress;

	event SetMoCStateAddress(address indexed mocStateAddress, address changerAddress);

	/**
	 * @dev initializes a new MoC state
	 *
	 * @param _mocStateAddress MoC state address
	 */
	constructor(address _mocStateAddress) public {
		setMoCStateAddress(_mocStateAddress);
	}

	/**
	 * @dev BPro USD PRICE
	 * @return the BPro USD Price [using mocPrecision]
	 */
	function latestAnswer() external view returns (int256) {
		IMoCState _mocState = IMoCState(mocStateAddress);
		return int256(_mocState.bproUsdPrice());
	}

	/**
	 * @dev returns the update time.
	 *
	 * @return always returns current block's timestamp
	 */
	function latestTimestamp() external view returns (uint256) {
		return now; // MoC state doesn't return update timestamp
	}

	/**
	 * @dev set MoC state address
	 *
	 * @param _mocStateAddress MoC state address
	 */
	function setMoCStateAddress(address _mocStateAddress) public ownerOnly {
		require(_mocStateAddress != address(0), "_mocStateAddress shall not be zero address");
		mocStateAddress = _mocStateAddress;
		emit SetMoCStateAddress(mocStateAddress, msg.sender);
	}
}
