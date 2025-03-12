// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./DustRefunder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./HomoraMath.sol";

import "../../interfaces/uniswapV2/IUniswapV2Router02.sol";
import "../../interfaces/uniswapV2/IUniswapV2Pair.sol";
import "../../interfaces/pancakeswap/ILiquidityZap.sol";
import "../../interfaces/IWETH.sol";

contract DlpUniswapPoolHelper is Initializable, OwnableUpgradeable, DustRefunder {
	using SafeERC20 for IERC20;
	using SafeMath for uint256;
	using HomoraMath for uint;

	address public lpTokenAddr;
	address public rdntAddr;
	address public wethAddr;

	IUniswapV2Router02 public router;
	ILiquidityZap public liquidityZap;
	address public mDLP;

	function __DlpUniswapPoolHelper_init(
		address _rdntAddr,
		address _wethAddr,
		address _routerAddr,
		ILiquidityZap _liquidityZap,
		address _lpTokenAddr,
		address _mDLP
	) external initializer {
		__Ownable_init();

		rdntAddr = _rdntAddr;
		wethAddr = _wethAddr;

		router = IUniswapV2Router02(_routerAddr);
		liquidityZap = _liquidityZap;

		lpTokenAddr = _lpTokenAddr;
		mDLP = _mDLP;
	}

	receive() external payable {}

	function zapWETH(uint256 amount) public returns (uint256 liquidity) {
		require(msg.sender == mDLP, "!mDLP only");
		IWETH weth = IWETH(wethAddr);
		weth.transferFrom(msg.sender, address(liquidityZap), amount);
		liquidity = liquidityZap.addLiquidityWETHOnly(amount, payable(address(this)));
		IERC20 lp = IERC20(lpTokenAddr);

		liquidity = lp.balanceOf(address(this));
		lp.safeTransfer(msg.sender, liquidity);
		refundDust(rdntAddr, wethAddr, msg.sender);
	}

	function getReserves() public view returns (uint256 rdnt, uint256 weth, uint256 lpTokenSupply) {
		IUniswapV2Pair lpToken = IUniswapV2Pair(lpTokenAddr);

		(uint256 reserve0, uint256 reserve1, ) = lpToken.getReserves();
		weth = lpToken.token0() != address(rdntAddr) ? reserve0 : reserve1;
		rdnt = lpToken.token0() == address(rdntAddr) ? reserve0 : reserve1;

		lpTokenSupply = lpToken.totalSupply();
	}

	// UniV2 / SLP LP Token Price
	// Alpha Homora Fair LP Pricing Method (flash loan resistant)
	// https://cmichel.io/pricing-lp-tokens/
	// https://blog.alphafinance.io/fair-lp-token-pricing/
	// https://github.com/AlphaFinanceLab/alpha-homora-v2-contract/blob/master/contracts/oracle/UniswapV2Oracle.sol
	function getLpPrice(uint rdntPriceInEth) public view returns (uint256 priceInEth) {
		IUniswapV2Pair lpToken = IUniswapV2Pair(lpTokenAddr);

		(uint reserve0, uint reserve1, ) = lpToken.getReserves();
		uint wethReserve = lpToken.token0() != address(rdntAddr) ? reserve0 : reserve1;
		uint rdntReserve = lpToken.token0() == address(rdntAddr) ? reserve0 : reserve1;

		uint lpSupply = lpToken.totalSupply();

		uint sqrtK = HomoraMath.sqrt(rdntReserve.mul(wethReserve)).fdiv(lpSupply); // in 2**112

		// rdnt in eth, decis 8
		uint px0 = rdntPriceInEth.mul(2 ** 112); // in 2**112
		// eth in eth, decis 8
		uint px1 = uint256(100000000).mul(2 ** 112); // in 2**112

		// fair token0 amt: sqrtK * sqrt(px1/px0)
		// fair token1 amt: sqrtK * sqrt(px0/px1)
		// fair lp price = 2 * sqrt(px0 * px1)
		// split into 2 sqrts multiplication to prevent uint overflow (note the 2**112)
		uint result = sqrtK.mul(2).mul(HomoraMath.sqrt(px0)).div(2 ** 56).mul(HomoraMath.sqrt(px1)).div(2 ** 56);
		priceInEth = result.div(2 ** 112);
	}

	function zapTokens(uint256 _wethAmt, uint256 _rdntAmt) public returns (uint256 liquidity) {
		require(msg.sender == mDLP, "!mDLP only");
		IWETH weth = IWETH(wethAddr);
		weth.transferFrom(msg.sender, address(this), _wethAmt);
		IERC20(rdntAddr).safeTransferFrom(msg.sender, address(this), _rdntAmt);
		IERC20(weth).safeApprove(address(liquidityZap), _wethAmt);
		IERC20(rdntAddr).safeApprove(address(liquidityZap), _rdntAmt);
		liquidity = liquidityZap.standardAdd(_rdntAmt, _wethAmt, address(this));
		IERC20 lp = IERC20(lpTokenAddr);
		liquidity = lp.balanceOf(address(this));
		lp.safeTransfer(msg.sender, liquidity);
		refundDust(rdntAddr, wethAddr, msg.sender);
	}

	function quoteFromToken(uint256 tokenAmount) public view returns (uint256 optimalWETHAmount) {
		return liquidityZap.quoteFromToken(tokenAmount);
	}

	function getLiquidityZap() public view returns (address) {
		return address(liquidityZap);
	}

	function setLiquidityZap(address _liquidityZap) external onlyOwner {
		require(_liquidityZap != address(0), "LiquidityZap can't be 0 address");
		liquidityZap = ILiquidityZap(_liquidityZap);
	}

	function setmDLP(address _mDLP) external onlyOwner {
		require(_mDLP != address(0), "mDLP can't be 0 address");
		mDLP = _mDLP;
	}

	function getPrice() public view returns (uint256 priceInEth) {
		(uint256 rdnt, uint256 weth, ) = getReserves();
		if (rdnt > 0) {
			priceInEth = weth.mul(10 ** 8).div(rdnt);
		}
	}
}