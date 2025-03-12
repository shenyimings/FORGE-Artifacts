// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IL2ECO is IERC20 {
    function linearInflationMultiplier() external view returns (uint256);
}
