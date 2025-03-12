// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IWithdrawalProcessor {
    function processWithdrawal(address account, uint256 underlyingAmount) external;
}
