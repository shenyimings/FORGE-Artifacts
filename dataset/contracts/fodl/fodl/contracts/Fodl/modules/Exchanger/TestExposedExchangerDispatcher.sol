// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './ExchangerDispatcher.sol';
import '../../mocks/ExchangerMock.sol';

contract TestExposedExchangerDispatcher is ExchangerDispatcher, ExchangeEventEmitter {
    function test_exchange(
        address adapter,
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes calldata txData
    ) external returns (uint256) {
        return exchange(adapter, fromToken, toToken, fromAmount, minToAmount, txData);
    }
}
