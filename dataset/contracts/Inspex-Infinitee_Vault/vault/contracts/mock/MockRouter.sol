// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interface/IUniswapRouterETH.sol";

contract MockRouter is IUniswapRouterETH {
    function getAmountsOut(uint256, address[] calldata)
        external
        view
        override
        returns (uint256[] memory amounts)
    {
        uint256[] memory out;
        return out;
    }

    function addLiquidity(
        address,
        address,
        uint256,
        uint256,
        uint256,
        uint256,
        address,
        uint256
    )
        external
        override
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        return (0, 0, 0);
    }

    function addLiquidityETH(
        address,
        uint256,
        uint256,
        uint256,
        address,
        uint256
    )
        external
        payable
        override
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        return (0, 0, 0);
    }

    function removeLiquidity(
        address,
        address,
        uint256,
        uint256,
        uint256,
        address,
        uint256
    ) external override returns (uint256 amountA, uint256 amountB) {
        return (0, 0);
    }

    function removeLiquidityETH(
        address,
        uint256,
        uint256,
        uint256,
        address,
        uint256
    ) external override returns (uint256 amountToken, uint256 amountETH) {
        return (0, 0);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        address[] calldata path,
        address to,
        uint256
    ) external override returns (uint256[] memory amounts) {
        IERC20 sellToken = IERC20(path[0]);
        IERC20 buyToken = IERC20(path[path.length - 1]);

        sellToken.transferFrom(msg.sender, address(this), amountIn);
        buyToken.transfer(to, amountIn);
        uint256[] memory out;
        return out;
    }

    function swapExactETHForTokens(
        uint256 ,
        address[] calldata,
        address,
        uint256
    ) external payable override returns (uint256[] memory amounts) {
        uint256[] memory out;
        return out;
    }

    function swapExactTokensForETH(
        uint256,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external override returns (uint256[] memory amounts) {
        uint256[] memory out;
        return out;
    }
}
