// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";

import "../../core/Globals.sol";

import "../../interfaces/gov/ERC20/IERC20Gov.sol";

library TokenBalance {
    using DecimalsConverter for *;
    using SafeERC20 for IERC20;
    using Math for uint256;

    enum TransferType {
        Revert,
        TryMint
    }

    function sendFunds(
        address token,
        address receiver,
        uint256 amount,
        TransferType transferType
    ) internal returns (uint256) {
        if (amount == 0) {
            return 0;
        }

        uint256 balance = normThisBalance(token);

        require(balance >= amount || transferType == TransferType.TryMint, "Insufficient funds");

        if (token == ETHEREUM_ADDRESS) {
            amount = amount.min(balance);

            if (amount > 0) {
                (bool status, ) = payable(receiver).call{value: amount}("");
                require(status, "Failed to send eth");
            }
        } else {
            if (balance < amount) {
                try
                    IERC20Gov(token).mint(address(this), (amount - balance).from18(token))
                {} catch {}

                amount = normThisBalance(token).min(amount);
            }

            uint256 amountWithDecimals = amount.from18(token);

            if (amountWithDecimals > 0) {
                IERC20(token).safeTransfer(receiver, amountWithDecimals);
            }
        }

        return amount;
    }

    function sendFunds(address token, address receiver, uint256 amount) internal {
        sendFunds(token, receiver, amount, TransferType.Revert);
    }

    function sendFunds(IERC20 token, address receiver, uint256 amount) internal {
        token.safeTransfer(receiver, amount.from18Safe(address(token)));
    }

    function thisBalance(address token) internal view returns (uint256) {
        return
            token == ETHEREUM_ADDRESS
                ? address(this).balance
                : IERC20(token).balanceOf(address(this));
    }

    function normThisBalance(address token) internal view returns (uint256) {
        return token == ETHEREUM_ADDRESS ? thisBalance(token) : thisBalance(token).to18(token);
    }
}
