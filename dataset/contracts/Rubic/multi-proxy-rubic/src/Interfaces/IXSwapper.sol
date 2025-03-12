// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IXSwapper {
    function swap(
        address aggregatorAdaptor,
        SwapDescription memory swapDesc,
        bytes memory aggregatorData,
        ToChainDescription calldata toChainDesc
    ) external payable;

    struct SwapDescription {
        address fromToken;
        address toToken;
        address receiver;
        uint256 amount;
        uint256 minReturnAmount;
    }

    struct ToChainDescription {
        uint32 toChainId;
        address toChainToken;
        uint256 expectedToChainTokenAmount;
        uint32 slippage;
    }
}
