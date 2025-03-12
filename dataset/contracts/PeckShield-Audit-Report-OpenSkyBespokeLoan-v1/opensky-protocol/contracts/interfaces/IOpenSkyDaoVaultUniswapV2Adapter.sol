// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyDaoVaultUniswapV2Adapter {
    event Swapped(address fromAsset, address toAsset, uint256 fromAmount, uint256 receivedAmount);

    function pullERC20FromDaoVault(address token, uint256 amount) external;

    function swapExactTokensForTokens(
        address assetToSwapFrom,
        address assetToSwapTo,
        uint256 amountToSwap,
        uint256 minAmountOut,
        bool useEthPath
    ) external returns (uint256);

    function swapTokensForExactTokens(
        address assetToSwapFrom,
        address assetToSwapTo,
        uint256 maxAmountToSwap,
        uint256 amountToReceive,
        bool useEthPath
    ) external returns (uint256);
}
