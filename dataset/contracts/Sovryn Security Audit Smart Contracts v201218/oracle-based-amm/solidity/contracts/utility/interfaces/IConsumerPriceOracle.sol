pragma solidity 0.4.26;

/*
    Chainlink Price Oracle interface
*/
interface IConsumerPriceOracle {
	function latestAnswer() external view returns (int256);

	function latestTimestamp() external view returns (uint256);
}
