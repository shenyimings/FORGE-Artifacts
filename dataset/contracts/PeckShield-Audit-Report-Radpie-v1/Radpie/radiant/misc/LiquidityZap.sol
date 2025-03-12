// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
// LiquidityZAP takes ETH and converts to  liquidity tokens.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// Attribution: CORE / cvault.finance
//  https://github.com/cVault-finance/CORE-periphery/blob/master/contracts/COREv1Router.sol
//
//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//----------------------------------------------------------------------------------
//    I n s t a n t
//
//        .:mmm.         .:mmm:.       .ii.  .:SSSSSSSSSSSSS.     .oOOOOOOOOOOOo.
//      .mMM'':Mm.     .:MM'':Mm:.     .II:  :SSs..........     .oOO'''''''''''OOo.
//    .:Mm'   ':Mm.   .:Mm'   'MM:.    .II:  'sSSSSSSSSSSSSS:.  :OO.           .OO:
//  .'mMm'     ':MM:.:MMm'     ':MM:.  .II:  .:...........:SS.  'OOo:.........:oOO'
//  'mMm'        ':MMmm'         'mMm:  II:  'sSSSSSSSSSSSSS'     'oOOOOOOOOOOOO'
//
//----------------------------------------------------------------------------------

import "../../libraries/uniswapV2/UniswapV2Library.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/IWETH.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LiquidityZap is Initializable, OwnableUpgradeable {
	using SafeERC20 for IERC20;
	using SafeMath for uint256;

	address public _token;
	address public _tokenWETHPair;
	IWETH public weth;
	bool private initialized;
	address public poolHelper;

	function __LiquidityZap_init() external initializer {
		__Ownable_init();
	}

	function initLiquidityZap(address token, address _weth, address tokenWethPair, address _helper) external {
		require(!initialized, "already initialized");
		_token = token;
		weth = IWETH(_weth);
		_tokenWETHPair = tokenWethPair;
		initialized = true;
		poolHelper = _helper;
	}

	fallback() external payable {
		if (msg.sender != address(weth)) {
			addLiquidityETHOnly(payable(msg.sender));
		}
	}

	function zapETH(address payable _onBehalf) external payable returns (uint256 liquidity) {
		require(msg.value > 0, "LiquidityZAP: ETH amount must be greater than 0");
		return addLiquidityETHOnly(_onBehalf);
	}

	function addLiquidityWETHOnly(uint256 _amount, address payable to) public returns (uint256 liquidity) {
		require(msg.sender == poolHelper, "!poolhelper");
		require(to != address(0), "Invalid address");
		uint256 buyAmount = _amount.div(2);
		require(buyAmount > 0, "Insufficient ETH amount");

		(uint256 reserveWeth, uint256 reserveTokens) = getPairReserves();
		uint256 outTokens = UniswapV2Library.getAmountOut(buyAmount, reserveWeth, reserveTokens);

		weth.transfer(_tokenWETHPair, buyAmount);

		(address token0, address token1) = UniswapV2Library.sortTokens(address(weth), _token);
		IUniswapV2Pair(_tokenWETHPair).swap(
			_token == token0 ? outTokens : 0,
			_token == token1 ? outTokens : 0,
			address(this),
			""
		);

		return _addLiquidity(outTokens, buyAmount, to);
	}

	function addLiquidityETHOnly(address payable to) public payable returns (uint256 liquidity) {
		require(to != address(0), "LiquidityZAP: Invalid address");
		uint256 buyAmount = msg.value.div(2);
		require(buyAmount > 0, "LiquidityZAP: Insufficient ETH amount");
		weth.deposit{value: msg.value}();

		(uint256 reserveWeth, uint256 reserveTokens) = getPairReserves();
		uint256 outTokens = UniswapV2Library.getAmountOut(buyAmount, reserveWeth, reserveTokens);

		weth.transfer(_tokenWETHPair, buyAmount);

		(address token0, address token1) = UniswapV2Library.sortTokens(address(weth), _token);
		IUniswapV2Pair(_tokenWETHPair).swap(
			_token == token0 ? outTokens : 0,
			_token == token1 ? outTokens : 0,
			address(this),
			""
		);

		return _addLiquidity(outTokens, buyAmount, to);
	}

	function quoteFromToken(uint256 tokenAmount) public view returns (uint256 optimalWETHAmount) {
		(uint256 wethReserve, uint256 tokenReserve) = getPairReserves();
		optimalWETHAmount = UniswapV2Library.quote(tokenAmount, tokenReserve, wethReserve);
	}

	function quote(uint256 wethAmount) public view returns (uint256 optimalTokenAmount) {
		(uint256 wethReserve, uint256 tokenReserve) = getPairReserves();
		optimalTokenAmount = UniswapV2Library.quote(wethAmount, wethReserve, tokenReserve);
	}

	// use with quote
	function standardAdd(uint256 tokenAmount, uint256 _wethAmt, address payable to) public returns (uint256 liquidity) {
		IERC20(_token).safeTransferFrom(msg.sender, address(this), tokenAmount);
		weth.transferFrom(msg.sender, address(this), _wethAmt);
		return _addLiquidity(tokenAmount, _wethAmt, to);
	}

	function _addLiquidity(
		uint256 tokenAmount,
		uint256 wethAmount,
		address payable to
	) internal returns (uint256 liquidity) {
		(uint256 wethReserve, uint256 tokenReserve) = getPairReserves();

		uint256 optimalTokenAmount = UniswapV2Library.quote(wethAmount, wethReserve, tokenReserve);

		uint256 optimalWETHAmount;
		if (optimalTokenAmount > tokenAmount) {
			optimalWETHAmount = UniswapV2Library.quote(tokenAmount, tokenReserve, wethReserve);
			optimalTokenAmount = tokenAmount;
		} else optimalWETHAmount = wethAmount;

		assert(weth.transfer(_tokenWETHPair, optimalWETHAmount));
		IERC20(_token).safeTransfer(_tokenWETHPair, optimalTokenAmount);

		liquidity = IUniswapV2Pair(_tokenWETHPair).mint(to);

		//refund dust
		if (tokenAmount > optimalTokenAmount) IERC20(_token).safeTransfer(to, tokenAmount.sub(optimalTokenAmount));
		if (wethAmount > optimalWETHAmount) {
			weth.transfer(to, wethAmount.sub(optimalWETHAmount));
		}
	}

	function getLPTokenPerEthUnit(uint256 ethAmt) public view returns (uint256 liquidity) {
		(uint256 reserveWeth, uint256 reserveTokens) = getPairReserves();
		uint256 outTokens = UniswapV2Library.getAmountOut(ethAmt.div(2), reserveWeth, reserveTokens);
		uint256 _totalSupply = IUniswapV2Pair(_tokenWETHPair).totalSupply();

		(address token0, ) = UniswapV2Library.sortTokens(address(weth), _token);
		(uint256 amount0, uint256 amount1) = token0 == _token ? (outTokens, ethAmt.div(2)) : (ethAmt.div(2), outTokens);
		(uint256 _reserve0, uint256 _reserve1) = token0 == _token
			? (reserveTokens, reserveWeth)
			: (reserveWeth, reserveTokens);
		liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
	}

	function getPairReserves() internal view returns (uint256 wethReserves, uint256 tokenReserves) {
		(address token0, ) = UniswapV2Library.sortTokens(address(weth), _token);
		(uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(_tokenWETHPair).getReserves();
		(wethReserves, tokenReserves) = token0 == _token ? (reserve1, reserve0) : (reserve0, reserve1);
	}
}