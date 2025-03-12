pragma solidity 0.4.26;

interface IOracle {
	function setK(uint256 _k) external;

	function write(uint256 price0, uint256 price1) external;

	function read()
		external
		returns (
			uint256 ema0,
			uint256 ema1,
			uint64 blockNumber,
			uint64 timestamp,
			uint256 lastCumulativePrice0,
			uint256 lastCumulativePrice1
		);

	//returns the price of a reserve in BTC (assuming one of the reserve is always BTC)
	function latestAnswer() external view returns (uint256);
}
