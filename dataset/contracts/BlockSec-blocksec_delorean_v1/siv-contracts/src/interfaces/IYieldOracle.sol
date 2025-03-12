//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

abstract contract IYieldOracle {
    function yieldToken() external virtual view returns (IERC20);
    function generatorToken() external virtual view returns (IERC20);

    // Returns the projected yield per token over the next `duration` seconds.
    function projectYield(uint256 amount, uint256 duration) external virtual view returns (uint256);
}
