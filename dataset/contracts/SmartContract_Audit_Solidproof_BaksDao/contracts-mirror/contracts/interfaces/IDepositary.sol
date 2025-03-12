// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import {IERC20} from "./ERC20.sol";

interface IDepositary {
    function getTotalValueLocked() external view returns (uint256 totalValueLocked);

    function getTotalValueLocked(IERC20 depositToken) external view returns (uint256 totalValueLocked);
}
