// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Mod is IERC20 {
    function decimals() external returns (uint8);

    function getPrice() external returns (uint256);

    function calculateFeeAmount(address, address) external returns (uint256);
}
