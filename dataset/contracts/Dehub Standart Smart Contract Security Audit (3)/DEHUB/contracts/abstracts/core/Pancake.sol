// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract Pancake is Ownable {
	using SafeMath for uint256;
	// Using Uniswap lib, because Pancakeswap forks are trash ATM...
	IUniswapV2Router02 internal uniswapV2Router;
	// We will call createPair() when we decide. To avoid snippers and bots.
	address internal uniswapV2Pair;
	// This will be set when we call initDEXRouter().
	address internal routerAddr;
	// To keep track of all LPs.
	mapping(address => bool) public liquidityPools;

	// To receive BNB from pancakeV2Router when swaping
	receive() external payable {}

	/**
	* @notice Initialises PCS router using the address. In addition creates a pair.
	* @param router Pancakeswap router address
	*/
	function initDEXRouter(address router) 
		external
		onlyOwner
	{
		// In case we already have set uniswapV2Pair before, remove it from LPs mapping.
		if (uniswapV2Pair != address(0)) {
			removeAddressFromLPs(uniswapV2Pair);
		}
		routerAddr = router;
		IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);
		uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
			address(this), 
			_uniswapV2Router.WETH()
		);
		uniswapV2Router = _uniswapV2Router;
		addAddressToLPs(uniswapV2Pair);
		emit RouterSet(router, uniswapV2Pair);
	}

	/**
	 * @notice Swaps passed tokens for BNB using Pancakeswap router and returns 
	 * actual amount received.
	 */
	function swapTokensForBnb(
		uint256 tokenAmount
	) internal returns(uint256) {
		uint256 initialBalance = address(this).balance;
		// generate the pancake pair path of token -> wbnb
		address[] memory path = new address[](2);
		path[0] = address(this);
		path[1] = uniswapV2Router.WETH();

		// Make the swap
		uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
			tokenAmount,
			0, // accept any amount of BNB
			path,
			address(this),
			block.timestamp
		);

		uint256 bnbReceived = address(this).balance.sub(initialBalance);
		return bnbReceived;
	}

	/**
	* @notice Adds address to a liquidity pool map. Can be called externaly.
	*/
	function addAddressToLPs(address lpAddr) public onlyOwner {
		liquidityPools[lpAddr] = true;
	}

	/**
	* @notice Removes address from a liquidity pool map. Can be called externaly.
	*/
	function removeAddressFromLPs(address lpAddr) public onlyOwner {
		liquidityPools[lpAddr] = false;
	}

/* --------------------------------- Events --------------------------------- */
	event RouterSet(address indexed router, address indexed pair);

/* -------------------------------- Modifiers ------------------------------- */
	modifier pcsInitialized {
		require(routerAddr != address(0), 'Router address has not been set!');
		require(uniswapV2Pair != address(0), 'PCS pair not created yet!');
		_;
	}
}