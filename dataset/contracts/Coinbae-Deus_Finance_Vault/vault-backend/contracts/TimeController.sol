//Be name khoda

pragma solidity >=0.6.0 <0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";

interface IUniswapV2Router01{
	function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
	function totalSupply() external view returns (uint256);
}

// DAI Time controller
 contract TimeController{
 	using SafeMath for uint256;

 	function calculateTime(address from, uint256 amount) public view returns (uint256){
 		return amount.div(10);
 	}
 }

// wETH Time controller
 contract TimeController{
 	using SafeMath for uint256;
 	IUniswapV2Router01 public uniswapRouter = IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
 	function calculateTime(address from, uint256 amount) public view returns (uint256){
 	    address[] memory path = new address[](2);
 	    path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
 	    path[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
 		uint256 usdcAmount = uniswapRouter.getAmountsOut(amount, path)[1];
 		return usdcAmount.mul(1e11);
 	}
 }


// wBTC Time controller
 contract TimeController{
 	using SafeMath for uint256;
 	IUniswapV2Router01 public uniswapRouter = IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
 	function calculateTime(address from, uint256 amount) public view returns (uint256){
 	    address[] memory path = new address[](2);
 	    path[0] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
 	    path[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
 		uint256 usdcAmount = uniswapRouter.getAmountsOut(amount, path)[1];
 		return usdcAmount.mul(1e11);
 	}
 }


// DEA Time controller
 contract TimeController{
 	using SafeMath for uint256;
 	IUniswapV2Router01 public uniswapRouter = IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
 	function calculateTime(address from, uint256 amount) public view returns (uint256){
 	    address[] memory path = new address[](2);
 	    path[0] = 0x80aB141F324C3d6F2b18b030f1C4E95d4d658778;
 	    path[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
 		uint256 usdcAmount = uniswapRouter.getAmountsOut(amount, path)[1];
 		return usdcAmount.mul(1e12);
 	}
 }


// DEUS Time controller
 contract TimeController{
 	using SafeMath for uint256;
 	IUniswapV2Router01 public uniswapRouter = IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
 	function calculateTime(address from, uint256 amount) public view returns (uint256){
 	    address[] memory path = new address[](3);
 	    path[0] = 0x3b62F3820e0B035cc4aD602dECe6d796BC325325;
 	    path[1] = 0x80aB141F324C3d6F2b18b030f1C4E95d4d658778;
 	    path[2] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
 		uint256 usdcAmount = uniswapRouter.getAmountsOut(amount, path)[2];
 		return usdcAmount.mul(1e12);
 	}
 }


// LP-DEA-USDC Time controller
 contract TimeController{
 	using SafeMath for uint256;
 	IUniswapV2Router01 public uniswapRouter = IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
 	IERC20 public lpToken = IERC20(0x83973dcaa04A6786ecC0628cc494a089c1AEe947);
 	IERC20 public usdcToken = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
 	function calculateTime(address from, uint256 amount) public view returns (uint256){
 		return usdcToken.balanceOf(0x83973dcaa04A6786ecC0628cc494a089c1AEe947).mul(2).mul(amount).div(lpToken.totalSupply()).mul(1e12);
 	}
 }


// LP-DEUS-ETH Time controller
 contract TimeController{
 	using SafeMath for uint256;
 	IUniswapV2Router01 public uniswapRouter = IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
 	IERC20 public lpToken = IERC20(0x4d9824fbc04EFf50AB1Dac614eaE4e20859D5c91);
 	IERC20 public wethToken = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
 	function calculateTime(address from, uint256 amount) public view returns (uint256){
 		uint256 wethAmount = wethToken.balanceOf(0x4d9824fbc04EFf50AB1Dac614eaE4e20859D5c91).mul(2).mul(amount).div(lpToken.totalSupply());
 		address[] memory path = new address[](2);
 	    path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
 	    path[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
 		uint256 usdcAmount = uniswapRouter.getAmountsOut(wethAmount, path)[1];
 		return usdcAmount.mul(1e12);
 	}
 }


// LP-DEUS-DEA Time controller
 contract TimeController{
 	using SafeMath for uint256;
 	IUniswapV2Router01 public uniswapRouter = IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
 	IERC20 public lpToken = IERC20(0x92Adab6d8dc13Dbd9052b291CFC1D07888299D65);
 	IERC20 public deaToken = IERC20(0x80aB141F324C3d6F2b18b030f1C4E95d4d658778);
 	function calculateTime(address from, uint256 amount) public view returns (uint256){
 		uint256 deaAmount = deaToken.balanceOf(0x92Adab6d8dc13Dbd9052b291CFC1D07888299D65).mul(2).mul(amount).div(lpToken.totalSupply());
 		address[] memory path = new address[](2);
 	    path[0] = 0x80aB141F324C3d6F2b18b030f1C4E95d4d658778;
 	    path[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
 		uint256 usdcAmount = uniswapRouter.getAmountsOut(deaAmount, path)[1];
 		return usdcAmount.mul(1e12);
 	}
 }