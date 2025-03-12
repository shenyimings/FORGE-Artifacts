// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IFlashLoanReceiver.sol";

contract MockFlashLoan is IFlashLoanReceiver {

    address public pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function executeOperation(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address sender,
        bytes calldata params
    ) external override returns (bool) {
        for (uint i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(pool, amounts[i]+premiums[i]);
        }
        return true;
    }
}