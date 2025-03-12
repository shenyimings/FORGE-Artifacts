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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITreasuryHandler} from "../interfaces/ITreasuryHandler.sol";

/**
 * @title Treasury handler interface
 * @dev Any class that implements this interface can be used for protocol-specific operations pertaining to the treasury.
 */
contract TreasuryHandlerStub is ITreasuryHandler {
    IERC20 public token;
    address public poolAddress;
    uint256 public calledTime;

    function setTokenAndPool(address _tokenAddress, address _poolAddress) external {
        token = IERC20(_tokenAddress);
        poolAddress = _poolAddress;
    }

    function processTreasury(address benefactor, address /* beneficiary */, uint256 /* amount */) external override {
        if (benefactor == address(0x0)) {
            return;
        }
        calledTime = calledTime + 1;
        uint256 tokenBalance = token.balanceOf(address(this));
        token.transfer(poolAddress, tokenBalance / 2);
        token.transfer(poolAddress, tokenBalance / 2);
    }
}
