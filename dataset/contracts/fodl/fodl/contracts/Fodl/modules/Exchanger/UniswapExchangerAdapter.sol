// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import './IExchanger.sol';
import './IUniswap.sol';

contract UniswapExchangerAdapter is IExchanger {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable ROUTER;

    constructor(address _router) public {
        require(_router != address(0), 'ICP0');
        ROUTER = _router;
    }

    function exchange(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes calldata
    ) external override returns (uint256) {
        address[] memory path = new address[](2);
        (path[0], path[1]) = (fromToken, toToken);

        IERC20(fromToken).safeIncreaseAllowance(ROUTER, fromAmount);

        uint256[] memory amounts = IUniswapRouterV2(ROUTER).swapExactTokensForTokens(
            fromAmount,
            minToAmount,
            path,
            address(this),
            block.timestamp
        );

        return amounts[1];
    }

    function getAmountOut(
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) external view override returns (uint256 toAmount) {
        address[] memory path = new address[](2);
        (path[0], path[1]) = (fromToken, toToken);

        toAmount = IUniswapRouterV2(ROUTER).getAmountsOut(fromAmount, path)[1];
    }

    function getAmountIn(
        address fromToken,
        address toToken,
        uint256 toAmount
    ) external view override returns (uint256 fromAmount) {
        address[] memory path = new address[](2);
        (path[0], path[1]) = (fromToken, toToken);

        fromAmount = IUniswapRouterV2(ROUTER).getAmountsIn(toAmount, path)[0];
    }

    function swapFromExact(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount
    ) external override returns (uint256 toAmount) {
        address[] memory path = new address[](2);
        (path[0], path[1]) = (fromToken, toToken);

        IERC20(fromToken).safeIncreaseAllowance(ROUTER, fromAmount);

        toAmount = IUniswapRouterV2(ROUTER).swapExactTokensForTokens(
            fromAmount,
            minToAmount,
            path,
            address(this),
            block.timestamp
        )[1];
    }

    function swapToExact(
        address fromToken,
        address toToken,
        uint256 maxFromAmount,
        uint256 toAmount
    ) external override returns (uint256 fromAmount) {
        address[] memory path = new address[](2);
        (path[0], path[1]) = (fromToken, toToken);

        IERC20(fromToken).safeIncreaseAllowance(ROUTER, maxFromAmount);

        fromAmount = IUniswapRouterV2(ROUTER).swapTokensForExactTokens(
            toAmount,
            maxFromAmount,
            path,
            address(this),
            block.timestamp
        )[0];
    }
}
