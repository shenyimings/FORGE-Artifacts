// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPoolHelper {
	function lpTokenAddr() external view returns (address);

	function zapWETH(uint256 amount) external returns (uint256);

	function zapTokens(uint256 _wethAmt, uint256 _rdntAmt) external returns (uint256);

	function quoteFromToken(uint256 tokenAmount) external view returns (uint256 optimalWETHAmount);

	function getLpPrice(uint rdntPriceInEth) external view returns (uint256 priceInEth);

	function getReserves() external view returns (uint256 rdnt, uint256 weth, uint256 lpTokenSupply);

	function getPrice() external view returns (uint256 priceInEth);
}

interface IBalancerPoolHelper is IPoolHelper {
	function initializePool(string calldata _tokenName, string calldata _tokenSymbol) external;
}

interface IUniswapPoolHelper is IPoolHelper {
	function initializePool() external;
}

interface ITestPoolHelper is IPoolHelper {
	function sell(uint256 _amount) external returns (uint256 amountOut);
}