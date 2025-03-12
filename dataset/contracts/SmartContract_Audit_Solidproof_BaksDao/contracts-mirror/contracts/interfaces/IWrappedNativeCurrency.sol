// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC20} from "./ERC20.sol";

interface IWrappedNativeCurrency is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
