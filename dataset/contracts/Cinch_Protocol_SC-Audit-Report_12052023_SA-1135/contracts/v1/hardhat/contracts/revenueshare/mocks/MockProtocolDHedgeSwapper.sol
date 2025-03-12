// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IYieldSourceDHedge.sol";

contract MockProtocolDHedgeSwapper {
    using SafeERC20 for IERC20;

    function withdraw(address pool, uint256 fundTokenAmount, IERC20, uint256) external {
        IERC20(pool).safeTransferFrom(msg.sender, address(this), fundTokenAmount);
        IYieldSourceDHedge(pool).withdrawTo(msg.sender, fundTokenAmount);
    }
}
