// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../ISwapPlace.sol";
import "../connector/SynapseStuff.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract SynapseSwapPlace is ISwapPlace {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    function swapPlaceType() external override pure returns (string memory) {
        return "SynapseSwapPlace";
    }

    function swap(SwapRoute calldata route) external override returns (uint256) {
        IERC20Upgradeable(route.tokenIn).safeIncreaseAllowance(route.pool, IERC20(route.tokenIn).balanceOf(address(this)));
        uint8 tokenInIndex = ISwap(route.pool).getTokenIndex(route.tokenIn);
        uint8 tokenOutIndex = ISwap(route.pool).getTokenIndex(route.tokenOut);
        uint256 transferBackAmount = ISwap(route.pool).swap(
            tokenInIndex,
            tokenOutIndex,
            route.amountIn,
            route.amountOut,
            block.timestamp
        );
        IERC20(route.tokenOut).transfer(msg.sender, IERC20(route.tokenOut).balanceOf(address(this)));
        return transferBackAmount;
    }


    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address pool
    ) external override view returns (uint256) {
        uint8 tokenInIndex = ISwap(pool).getTokenIndex(tokenIn);
        uint8 tokenOutIndex = ISwap(pool).getTokenIndex(tokenOut);
        return ISwap(pool).calculateSwap(tokenInIndex, tokenOutIndex, amountIn);
    }

}


