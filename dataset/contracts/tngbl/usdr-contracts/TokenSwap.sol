// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./constants/roles.sol";
import "./interfaces/ITokenSwap.sol";

contract TokenSwap is ITokenSwap, AccessControl {
    struct TokenSwapData {
        address router;
        address[] path;
    }
    using SafeERC20 for IERC20;

    mapping(bytes => TokenSwapData) public swappers;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROUTER_POLICY_ROLE, msg.sender);
    }

    function addSwapRoute(
        address router,
        address tokenInAddress,
        address tokenOutAddress,
        address[] calldata routerPath,
        address[] calldata routerPathReverse
    ) external onlyRole(ROUTER_POLICY_ROLE) {
        require(
            ((routerPath[0] == tokenInAddress &&
                routerPath[routerPath.length - 1] == tokenOutAddress) &&
                (routerPathReverse[0] == tokenOutAddress &&
                    routerPathReverse[routerPathReverse.length - 1] ==
                    tokenInAddress)),
            "invalid route"
        );
        bytes memory tokenized = abi.encodePacked(
            tokenInAddress,
            tokenOutAddress
        );
        bytes memory tokenizedReverse = abi.encodePacked(
            tokenOutAddress,
            tokenInAddress
        );
        swappers[tokenized] = TokenSwapData(router, routerPath);
        swappers[tokenizedReverse] = TokenSwapData(router, routerPathReverse);
    }

    function removeSwapRoute(address tokenInAddress, address tokenOutAddress)
        external
        onlyRole(ROUTER_POLICY_ROLE)
    {
        bytes memory tokenized = abi.encodePacked(
            tokenInAddress,
            tokenOutAddress
        );
        bytes memory tokenizedReverse = abi.encodePacked(
            tokenOutAddress,
            tokenInAddress
        );
        delete swappers[tokenized];
        delete swappers[tokenizedReverse];
    }

    function exchange(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        EXCHANGE_TYPE exchangeType
    ) external override returns (uint256) {
        bytes memory tokenized = abi.encodePacked(tokenIn, tokenOut);
        address[] memory path = swappers[tokenized].path;
        //take the token
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        //approve the router
        IERC20(tokenIn).approve(swappers[tokenized].router, amountIn);

        uint256[] memory amounts;
        if (exchangeType == EXCHANGE_TYPE.EXACT_INPUT) {
            amounts = IUniswapV2Router01(swappers[tokenized].router)
                .swapExactTokensForTokens(
                    amountIn,
                    amountOut,
                    path,
                    address(this),
                    block.timestamp + 30 // on sushi?
                );
        } else if (exchangeType == EXCHANGE_TYPE.EXACT_OUTPUT) {
            amounts = IUniswapV2Router01(swappers[tokenized].router)
                .swapTokensForExactTokens(
                    amountOut,
                    amountIn,
                    path,
                    address(this),
                    block.timestamp + 30 // on sushi?
                );
        }
        //send converted to caller
        IERC20(tokenOut).safeTransfer(msg.sender, amounts[amounts.length - 1]);
        return amounts[amounts.length - 1]; //returns output token amount
    }

    function quoteOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view override returns (uint256) {
        bytes memory tokenized = abi.encodePacked(tokenIn, tokenOut);
        address[] memory path = swappers[tokenized].path;

        uint256[] memory amounts = IUniswapV2Router01(
            swappers[tokenized].router
        ).getAmountsOut(amountIn, path);
        return amounts[path.length - 1];
    }

    function quoteIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) external view override returns (uint256) {
        bytes memory tokenized = abi.encodePacked(tokenIn, tokenOut);
        address[] memory path = swappers[tokenized].path;

        uint256[] memory amounts = IUniswapV2Router01(
            swappers[tokenized].router
        ).getAmountsIn(amountOut, path);
        return amounts[0];
    }
}
