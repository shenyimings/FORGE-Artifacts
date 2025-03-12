// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../external/@openzeppelin/token/ERC20/IERC20.sol";

/// @notice Common Spool contracts constants
abstract contract BaseConstants {
    uint256 internal constant FULL_PERCENT = 100_00; // 2 digits precision
    uint256 internal constant ACCURACY = 10**30;
}

abstract contract USDC {
    IERC20 internal constant USDC_ADDRESS = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
}