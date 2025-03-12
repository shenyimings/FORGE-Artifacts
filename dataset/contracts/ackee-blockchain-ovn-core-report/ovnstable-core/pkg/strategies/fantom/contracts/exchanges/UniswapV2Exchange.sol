// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../connectors/uniswap/v2/interfaces/IUniswapV2Router02.sol";
import "../libraries/OvnMath.sol";

abstract contract UniswapV2Exchange {

    uint256 constant public BASIS_POINTS_FOR_SLIPPAGE = 4;

    IUniswapV2Router02 private uniswapRouter;

    function _setUniswapRouter(address _uniswapRouter) internal {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    function _swapExactTokensForTokens(
        address inputToken,
        address outputToken,
        uint256 amountInput,
        address recipient
    ) internal returns (uint256) {

        uint256 amountOutMin = _getAmountsOut(inputToken, outputToken, amountInput);
        IERC20(inputToken).approve(address(uniswapRouter), amountInput);

        address[] memory path = new address[](2);
        path[0] = inputToken;
        path[1] = outputToken;

        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            amountInput,
            OvnMath.subBasisPoints(amountOutMin, BASIS_POINTS_FOR_SLIPPAGE),
            path,
            recipient,
            block.timestamp + 600
        );

        return amounts[1];
    }

    function _getAmountsOut(
        address inputToken,
        address outputToken,
        uint256 amountInput
    ) internal view returns (uint256) {

        address[] memory path = new address[](2);
        path[0] = inputToken;
        path[1] = outputToken;

        uint[] memory amounts = uniswapRouter.getAmountsOut(amountInput, path);

        return amounts[1];
    }


    uint256[49] private __gap;
}
