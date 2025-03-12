// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ISwapRouter} from "../../src/interfaces/uniswap/ISwapRouter.sol";

contract SwapRouter is ISwapRouter {
    using FixedPointMathLib for uint256;

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        ERC20 tokenIn = ERC20(params.tokenIn);
        ERC20 tokenOut = ERC20(params.tokenOut);

        require(
            tokenIn.allowance(msg.sender, address(this)) >= params.amountIn,
            "MockSwapRouter: INSUFFICIENT_TOKEN_IN_ALLOWANCE"
        );
        require(
            tokenOut.balanceOf(address(this)) >= params.amountOutMinimum,
            "MockSwapRouter: INSUFFICIENT_TOKEN_OUT_BALANCE"
        );

        tokenIn.transferFrom(msg.sender, address(this), params.amountIn);
        tokenOut.transfer(msg.sender, params.amountOutMinimum);

        return params.amountOutMinimum;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 /* amountIn */ )
    {
        ERC20 tokenIn = ERC20(params.tokenIn);
        ERC20 tokenOut = ERC20(params.tokenOut);
        require(
            tokenIn.allowance(msg.sender, address(this)) >= params.amountInMaximum,
            "MockSwapRouter: INSUFFICIENT_TOKEN_IN_ALLOWANCE"
        );
        require(
            tokenOut.balanceOf(address(this)) >= params.amountOut,
            "MockSwapRouter: INSUFFICIENT_TOKEN_OUT_BALANCE"
        );

        tokenIn.transferFrom(msg.sender, address(this), params.amountInMaximum);
        tokenOut.transfer(msg.sender, params.amountOut);

        return params.amountOut;
    }
}
