// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStEth is IERC20 {
    function submit(address) external payable;
}
