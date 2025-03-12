// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../src/interfaces/balancer/IVault.sol";
import "../../src/interfaces/balancer/IFlashLoanRecipient.sol";

contract BalancerVault is IVault {

    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external override { 
        uint256[] memory feeAmounts = new uint256[](tokens.length);
        uint256[] memory preLoanBalances = new uint256[](tokens.length);

        IERC20 token = IERC20(tokens[0]);
        uint256 amount = amounts[0];

        preLoanBalances[0] = token.balanceOf(address(this));

        require(preLoanBalances[0] >= amount);
        token.transfer(address(recipient), amount);

        IFlashLoanRecipient(recipient).receiveFlashLoan(tokens, amounts, feeAmounts, userData);

        uint256 preLoanBalance = preLoanBalances[0];

        // Checking for loan repayment first (without accounting for fees) makes for simpler debugging, and results
        // in more accurate revert reasons if the flash loan protocol fee percentage is zero.
        uint256 postLoanBalance = token.balanceOf(address(this));
        require(postLoanBalance >= preLoanBalance);

        // No need for checked arithmetic since we know the loan was fully repaid.
        uint256 receivedFeeAmount = postLoanBalance - preLoanBalance;
        require(receivedFeeAmount >= feeAmounts[0]);
    }
}