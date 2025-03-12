// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILiquidityZap {
	function _WETH() external view returns (address);

	function _token() external view returns (address);

	function _tokenWETHPair() external view returns (address);

	function addLiquidityETHOnly(address to) external returns (uint256 liquidity);

	function addLiquidityTokensOnly(
		address from,
		address to,
		uint256 amount
	) external returns (uint256 liquidity);

	function getLPTokenPerEthUnit(uint256 ethAmt) external view returns (uint256 liquidity);

	function initLiquidityZap(
		address token,
		address WETH,
		address tokenWethPair,
		address helper
	) external;

	function quote(uint256 wethAmount) external view returns (uint256 optimalTokenAmount);

	function quoteFromToken(uint256 tokenAmount) external view returns (uint256 optimalWETHAmount);

	function removeAllLiquidityETHOnly(address to) external returns (uint256 amount);

	function removeAllLiquidityTokenOnly(address to) external returns (uint256 amount);

	function removeLiquidity(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		address to
	) external returns (uint256 amountA, uint256 amountB);

	function removeLiquidityETHOnly(address to, uint256 liquidity) external returns (uint256 amountOut);

	function removeLiquidityTokenOnly(address to, uint256 liquidity) external returns (uint256 amount);

	function standardAdd(
		uint256 tokenAmount,
		uint256 _wethAmt,
		address to
	) external payable returns (uint256 liquidity);

	function unzap() external returns (uint256 amountToken, uint256 amountETH);

	function unzapToETH() external returns (uint256 amount);

	function unzapToTokens() external returns (uint256 amount);

	function zapETH(address payable _onBehalf) external payable returns (uint256 liquidity);

	function zapTokens(uint256 amount) external returns (uint256 liquidity);

	function addLiquidityWETHOnly(uint256 _amount, address payable to) external returns (uint256 liquidity);

	struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

	function increaseLiquidity(IncreaseLiquidityParams calldata params)
    	external
    	payable
   		returns (
        	uint128 liquidity,
        	uint256 amount0,
        	uint256 amount1
    );

	struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

	function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
    );

}