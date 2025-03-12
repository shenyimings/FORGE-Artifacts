pragma solidity >=0.5.0 <0.6.0;

/*
    Chainlink Price Oracle interface
*/
interface IConsumerPriceOracle {
	function latestAnswer() external view returns (int256);

	function latestTimestamp() external view returns (uint256);
}
