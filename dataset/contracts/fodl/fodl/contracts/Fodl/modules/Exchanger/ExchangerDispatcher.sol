// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/utils/Address.sol';

import './IExchanger.sol';

contract ExchangerDispatcher {
    using Address for address;

    function exchange(
        address adapter,
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes memory txData
    ) internal returns (uint256) {
        bytes memory returnData = adapter.functionDelegateCall(
            abi.encodeWithSelector(IExchanger.exchange.selector, fromToken, toToken, fromAmount, minToAmount, txData)
        );
        return abi.decode(returnData, (uint256));
    }

    function swapToExact(
        address adapter,
        address fromToken,
        address toToken,
        uint256 maxFromAmount,
        uint256 toAmount
    ) internal returns (uint256) {
        bytes memory returnData = adapter.functionDelegateCall(
            abi.encodeWithSelector(IExchanger.swapToExact.selector, fromToken, toToken, maxFromAmount, toAmount)
        );
        return abi.decode(returnData, (uint256));
    }

    function swapFromExact(
        address adapter,
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount
    ) internal returns (uint256) {
        bytes memory returnData = adapter.functionDelegateCall(
            abi.encodeWithSelector(IExchanger.swapFromExact.selector, fromToken, toToken, fromAmount, minToAmount)
        );
        return abi.decode(returnData, (uint256));
    }

    function getAmountOut(
        address adapter,
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) internal returns (uint256) {
        bytes memory returnData = adapter.functionDelegateCall(
            abi.encodeWithSelector(IExchanger.getAmountOut.selector, fromToken, toToken, fromAmount)
        );
        return abi.decode(returnData, (uint256));
    }

    function getAmountIn(
        address adapter,
        address fromToken,
        address toToken,
        uint256 toAmount
    ) internal returns (uint256) {
        bytes memory returnData = adapter.functionDelegateCall(
            abi.encodeWithSelector(IExchanger.getAmountIn.selector, fromToken, toToken, toAmount)
        );
        return abi.decode(returnData, (uint256));
    }
}
