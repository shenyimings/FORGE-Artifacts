// SPDX-License-Identifier: MIT

import '@openzeppelin/contracts/utils/Address.sol';

import '../modules/Exchanger/IExchanger.sol';

pragma solidity 0.6.12;

interface ExchangeEventEmitter {
    event Exchange(address fromToken, address toToken, uint256 fromAmount, uint256 minToAmount, bytes txData);
    event SwapFromExact(address fromToken, address toToken, uint256 fromAmount, uint256 minToAmount);
    event SwapToExact(address fromToken, address toToken, uint256 maxFromAmount, uint256 toAmount);
}

contract ExchangerMock is IExchanger, ExchangeEventEmitter {
    uint256 private immutable outputToAmount;

    constructor(uint256 _outputToAmount) public {
        outputToAmount = _outputToAmount;
    }

    function exchange(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes memory txData
    ) external override returns (uint256) {
        emit Exchange(fromToken, toToken, fromAmount, minToAmount, txData);
        return outputToAmount;
    }

    function getAmountOut(
        address,
        address,
        uint256
    ) external view override returns (uint256) {
        return outputToAmount;
    }

    function getAmountIn(
        address,
        address,
        uint256
    ) external view override returns (uint256) {
        return outputToAmount;
    }

    function swapFromExact(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount
    ) external override returns (uint256 toAmount) {
        emit SwapFromExact(fromToken, toToken, fromAmount, minToAmount);
        return outputToAmount;
    }

    function swapToExact(
        address fromToken,
        address toToken,
        uint256 maxFromAmount,
        uint256 toAmount
    ) external override returns (uint256 fromAmount) {
        emit SwapToExact(fromToken, toToken, maxFromAmount, toAmount);
        return outputToAmount;
    }
}
