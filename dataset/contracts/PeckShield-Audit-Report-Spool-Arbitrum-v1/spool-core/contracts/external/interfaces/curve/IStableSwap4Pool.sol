// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ICurvePool.sol";

interface IStableSwap4Pool is ICurvePool {
    function add_liquidity(uint256[4] calldata amounts, uint256 min_lp) external;
}
