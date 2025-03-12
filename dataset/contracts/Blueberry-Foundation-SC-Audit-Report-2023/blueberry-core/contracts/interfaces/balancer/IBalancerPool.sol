// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IBalancerPool {
    function getFinalTokens() external view returns (address[] memory);

    function getNormalizedWeight(address token) external view returns (uint256);

    function getSwapFee() external view returns (uint256);

    function getNumTokens() external view returns (uint256);

    function getBalance(address token) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function joinPool(uint256 poolAmountOut, uint256[] calldata maxAmountsIn)
        external;

    function swapExactAmountOut(
        address tokenIn,
        uint256 maxAmountIn,
        address tokenOut,
        uint256 tokenAmountOut,
        uint256 maxPrice
    ) external returns (uint256 tokenAmountIn, uint256 spotPriceAfter);

    function joinswapExternAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        uint256 minPoolAmountOut
    ) external returns (uint256 poolAmountOut);

    function exitPool(uint256 poolAmoutnIn, uint256[] calldata minAmountsOut)
        external;

    function exitswapExternAmountOut(
        address tokenOut,
        uint256 tokenAmountOut,
        uint256 maxPoolAmountIn
    ) external returns (uint256 poolAmountIn);
}
