// SPDX-License-Identifier: MIT

pragma solidity >=0.8.14;

interface IPeripheryPayments {
    function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;

    function refundETH() external payable;

    function sweepToken(address tokenAddr, uint256 amountMinimum, address recipient) external payable;
}
