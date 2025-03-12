// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "./Structures.sol";


interface ISwapPlace is Structures {

    function swapPlaceType() external view returns (string memory);

    function swap(
        SwapRoute calldata route
    ) external returns (uint256);

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address pool
    ) external view returns (uint256);

}
