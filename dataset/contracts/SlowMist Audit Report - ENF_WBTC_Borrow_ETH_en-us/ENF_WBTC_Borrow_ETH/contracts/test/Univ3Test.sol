// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface IUniswapV3Router is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IWeth {
    function withdraw(uint256 wad) external;
}

contract UniV3Test {
    address router2 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address crv = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address usdc = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    receive() external payable {}

    constructor() {}

    function swap(uint256 amount) public payable {
        // IERC20(crv).transferFrom(msg.sender, address(this), amount);

        // IERC20(crv).approve(router2, 0);
        // IERC20(crv).approve(router2, 100000000000000000000000000000000000);

        IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
            tokenIn: weth,
            tokenOut: crv,
            fee: uint24(3000),
            recipient: address(this),
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: uint160(0)
        });

        uint256 amountOut = IUniswapV3Router(router2).exactInputSingle{value: msg.value}(params);
        console.log(amountOut);

        uint256 wethOut = IERC20(crv).balanceOf(address(this));
        console.log("WETH out: ", wethOut);
        IWeth(weth).withdraw(wethOut);

        uint256 swapped = address(this).balance;
        console.log("ETH out: ", swapped);
    }
}
