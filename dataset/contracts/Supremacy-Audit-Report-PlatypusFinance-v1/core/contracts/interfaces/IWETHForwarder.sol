// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

interface IWETHForwarder {
    function unwrapAndTransfer(address payable to, uint256 amount) external;
}
