// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {IVault} from "../../../src/interfaces/balancer/IVault.sol";
import {IFlashLoanRecipient} from "../../../src/interfaces/balancer/IFlashLoanRecipient.sol";
import {MockWETH} from "../MockWETH.sol";

contract MockBalancerVault is IVault {
    MockWETH public weth;

    constructor(MockWETH _weth) {
        weth = _weth;
    }

    function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData)
        external
        override
    {
        require(recipient != address(0), "MockBalancerVault: INVALID_RECIPIENT");
        require(tokens.length == 1, "MockBalancerVault: INVALID_TOKENS_LENGTH");
        require(amounts.length == 1, "MockBalancerVault: INVALID_AMOUNTS_LENGTH");

        require(tokens[0] == address(weth), "MockBalancerVault: INVALID_TOKEN");
        require(amounts[0] <= weth.balanceOf(address(this)), "MockBalancerVault: INSUFFICIENT_WETH_BALANCE");

        uint256 initialBalance = weth.balanceOf(address(this));
        uint256[] memory feeAmounts;

        weth.transfer(recipient, amounts[0]);
        IFlashLoanRecipient(recipient).receiveFlashLoan(tokens, amounts, feeAmounts, userData);

        require(weth.balanceOf(address(this)) == initialBalance, "MockBalancerVault: FLASH_LOAN_NOT_RETURNED");
    }
}
