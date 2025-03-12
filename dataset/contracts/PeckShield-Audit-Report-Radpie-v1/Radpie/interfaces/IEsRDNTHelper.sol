// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IEsRDNTHelper {
    
    event swappedRdntToEsRdnt( uint256 amountIn, uint256 amountOut );
    event swappedEsRdntToRdnt( uint256 amountIn, uint256 amountOut);

    function swapRDNTToEsRDNT(
        uint256 amountToSwap,
        uint160 sqrtPriceLimit,
        uint256 amountOutMin
    ) external returns (uint256 amountOut);

    function swapEsRDNTToRDNT(
        uint256 amountToSwap,
        uint160 sqrtPriceLimit,
        uint256 amountOutMin
    ) external returns (uint256 amountOut);

    function swapEsRDNTToRDNTFor(
        uint256 amountToSwap,
        uint256 amountOutMin,
        uint160 sqrtPriceLimit,
        address receiver
    ) external returns (uint256 amountOut);
}
