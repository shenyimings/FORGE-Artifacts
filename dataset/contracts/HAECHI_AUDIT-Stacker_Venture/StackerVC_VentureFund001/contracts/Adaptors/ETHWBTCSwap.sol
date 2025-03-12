// SPDX-License-Identifier: MIT
/*
	Adaptor to allow the FarmBoss_WBTC to sell ETH gains for more WBTC on Uniswap/Sushiswap.

	We can also allow WBTC to be sold for ETH, if needed (reverse). However this will not be whitelisted initially.
*/

pragma solidity ^0.6.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol"; // call ERC20 safely
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../Interfaces/IUniswapRouterV2.sol";

contract ETHWBTCSwap {
	using SafeERC20 for IERC20;
	using SafeMath for uint256;
	using Address for address;

	address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
	address public constant FarmBossWBTC = 0xCbAb999b25850c6530bcA365e5005702CB6Bf006;

	address public constant SushiswapRouter = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
	address public constant UniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

	constructor() public {
		IERC20(WBTC).safeApprove(SushiswapRouter, type(uint256).max);
		IERC20(WBTC).safeApprove(UniswapRouter, type(uint256).max);
	}

	function swapExactETHForWBTC(bytes calldata _data, bool _isSushi) external payable returns (uint[] memory amounts){

		(uint256 amountOutMin, address[] memory path, address to, uint256 deadline) = abi.decode(_data[4:], (uint256, address[], address, uint256));

		require(path[0] == WETH && path[1] == WBTC && path.length == 2, "ETHWBTCSwap: invalid path");
		require(to == FarmBossWBTC, "ETHWBTCSwap: invalid destination");

		if (_isSushi){
			return IUniswapRouterV2(SushiswapRouter).swapExactETHForTokens{value: msg.value}(amountOutMin, path, to, deadline);
		}
		else {
			return IUniswapRouterV2(UniswapRouter).swapExactETHForTokens{value: msg.value}(amountOutMin, path, to, deadline);
		}
	}

	function swapExactWBTCForETH(bytes calldata _data, bool _isSushi) external returns (uint[] memory amounts){

		(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline) = abi.decode(_data[4:], (uint256, uint256, address[], address, uint256));

		require(path[0] == WBTC && path[1] == WETH && path.length == 2, "ETHWBTCSwap: invalid path 2");
		require(to == FarmBossWBTC, "ETHWBTCSwap: invalid destination 2");

		// pull the WBTC for swapping from caller
		IERC20(WBTC).safeTransferFrom(msg.sender, address(this), amountIn);

		// WBTC already approved for swap in constructor

		if (_isSushi){
			return IUniswapRouterV2(SushiswapRouter).swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);
		}
		else {
			return IUniswapRouterV2(UniswapRouter).swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);
		}
	}

}