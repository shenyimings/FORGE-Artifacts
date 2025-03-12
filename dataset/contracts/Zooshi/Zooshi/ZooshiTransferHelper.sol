pragma solidity ^0.6.2;

// SPDX-License-Identifier: MIT

import "./Ownable.sol";
import "./IERC20.sol";
import "./IUniswapV2Router.sol";

contract ZooshiTransferHelper is Ownable {
	IUniswapV2Router02 uniswapV2Router;

	constructor(address routerAddress) public {
		uniswapV2Router = IUniswapV2Router02(routerAddress);
	}

	function buy(address tokenAddress) public payable onlyOwner returns (uint256) {
		address self = address(this);
		IERC20 token = IERC20(tokenAddress);

		// create swap path
		address[] memory path = new address[](2);
		path[0] = uniswapV2Router.WETH();
		path[1] = tokenAddress;

		// buy tokens
		uint256 previousBalance = token.balanceOf(self);
		uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(0, path, self, block.timestamp);
		uint256 amountOut = token.balanceOf(self) - previousBalance;

		// transfer back to owner address
		uint256 previousTokenBalance = token.balanceOf(owner());
		require(token.transfer(owner(), amountOut), "Token transfer failed.");
		return token.balanceOf(owner()) - previousTokenBalance;
	}
}