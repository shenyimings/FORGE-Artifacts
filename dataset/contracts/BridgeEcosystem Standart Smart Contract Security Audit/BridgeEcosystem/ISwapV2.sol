// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

interface ISwapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface ISwapRouterV2 {
    function WETH() external pure returns (address);

    function factory() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}