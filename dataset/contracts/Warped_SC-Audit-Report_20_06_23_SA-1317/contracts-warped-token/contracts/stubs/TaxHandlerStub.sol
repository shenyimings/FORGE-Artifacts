// SPDX-License-Identifier: MIT

/**
 __      __  _____ _______________________________________   
/  \    /  \/  _  \\______   \______   \_   _____/\______ \  
\   \/\/   /  /_\  \|       _/|     ___/|    __)_  |    |  \ 
 \        /    |    \    |   \|    |    |        \ |    `   \
  \__/\  /\____|__  /____|_  /|____|   /_______  //_______  /
       \/         \/       \/                  \/         \/ 
 */

pragma solidity 0.8.18;

import {ITaxHandler} from "../interfaces/ITaxHandler.sol";

contract TaxHandlerStub is ITaxHandler {
    uint256 private _taxAmount;

    function setTestData(uint256 taxAmount) external {
        _taxAmount = taxAmount;
    }

    function getTax(
        address /* benefactor */,
        address /* beneficiary */,
        uint256 /* amount */
    ) external view override returns (uint256) {
        return _taxAmount;
    }
}
