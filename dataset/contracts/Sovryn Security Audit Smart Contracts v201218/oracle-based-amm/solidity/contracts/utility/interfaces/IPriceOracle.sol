pragma solidity 0.4.26;
import "./IConsumerPriceOracle.sol";
import "../../token/interfaces/IERC20Token.sol";

/*
    Price Oracle interface
*/
contract IPriceOracle {
	function latestRate(IERC20Token _tokenA, IERC20Token _tokenB) public view returns (uint256, uint256);

	function lastUpdateTime() public view returns (uint256);

	function latestRateAndUpdateTime(IERC20Token _tokenA, IERC20Token _tokenB)
		public
		view
		returns (
			uint256,
			uint256,
			uint256
		);

	function tokenAOracle() public view returns (IConsumerPriceOracle) {
		this;
	}

	function tokenBOracle() public view returns (IConsumerPriceOracle) {
		this;
	}
}
