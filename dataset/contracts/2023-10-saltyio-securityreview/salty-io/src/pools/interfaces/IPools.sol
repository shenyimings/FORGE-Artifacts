// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../dao/interfaces/IDAO.sol";


interface IPools
	{
	function setDAO( IDAO _dao ) external;

	function addLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minLiquidityReceived, uint256 deadline ) external returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity);
	function removeLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToRemove, uint256 minReclaimedA, uint256 minReclaimedB, uint256 deadline ) external returns (uint256 reclaimedA, uint256 reclaimedB);
	function deposit( IERC20 token, uint256 amount ) external;
	function withdraw( IERC20 token, uint256 amount ) external;
	function swap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline ) external returns (uint256 swapAmountOut);
	function depositSwapWithdraw(IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline) external returns (uint256 swapAmountOut);
	function dualZapInLiquidity(IERC20 tokenA, IERC20 tokenB, uint256 zapAmountA, uint256 zapAmountB, uint256 minLiquidityReceived, uint256 deadline, bool bypassSwap ) external returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity);

	function setIsWhitelisted(bytes32 poolID) external;
	function clearIsWhitelisted(bytes32 poolID) external;

	function depositTokenForCounterswap( address counterswapAddress, IERC20 tokenToDeposit, uint256 amountToDeposit ) external;
	function withdrawTokenFromCounterswap( address counterswapAddress, IERC20 tokenToWithdraw, uint256 amountToWithdraw ) external;

	// Views
	function totalLiquidity(bytes32 poolID) external view returns (uint256);
	function getPoolReserves(IERC20 tokenA, IERC20 tokenB) external view returns (uint256 reserveA, uint256 reserveB);
	function depositedBalance(address user, IERC20 token) external view returns (uint256);
	function getUserLiquidity(address user, IERC20 tokenA, IERC20 tokenB) external view returns (uint256);
	}

