// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { IERC20 } from "@oz/token/ERC20/IERC20.sol";
import { TransferHelper } from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import { Errors } from "../../core/errors/Errors.sol";
import { IPeripheryPayments } from "../interfaces/IPeripheryPayments.sol";
import { IWETH9 } from "../interfaces/external/IWETH9.sol";
import { PeripheryImmutableState } from "./PeripheryImmutableState.sol";

abstract contract PeripheryPayments is IPeripheryPayments, PeripheryImmutableState {
    receive() external payable {
        if (msg.sender != WETH9) {
            revert Errors.NotWETH9();
        }
    }

    function unwrapWETH9(uint256 amountMinimum, address recipient) public payable override {
        uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));
        if (balanceWETH9 < amountMinimum) {
            revert Errors.Insufficient();
        }

        if (balanceWETH9 > 0) {
            IWETH9(WETH9).withdraw(balanceWETH9);
            TransferHelper.safeTransferETH(recipient, balanceWETH9);
        }
    }

    function sweepToken(address token, uint256 amountMinimum, address recipient) public payable override {
        uint256 balanceToken = IERC20(token).balanceOf(address(this));
        if (balanceToken < amountMinimum) {
            revert Errors.Insufficient();
        }

        if (balanceToken > 0) {
            TransferHelper.safeTransfer(token, recipient, balanceToken);
        }
    }

    function refundETH() external payable override {
        if (address(this).balance > 0) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        }
    }

    function pay(address tokenAddr, address payer, address recipient, uint256 value) internal {
        if (tokenAddr == WETH9 && address(this).balance >= value) {
            // pay with WETH9
            IWETH9(WETH9).deposit{ value: value }(); // wrap only what is needed
                // to pay
            IWETH9(WETH9).transfer(recipient, value);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input
            // multihop case)
            TransferHelper.safeTransfer(tokenAddr, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(tokenAddr, payer, recipient, value);
        }
    }
}
