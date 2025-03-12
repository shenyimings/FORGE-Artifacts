// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ICurvePool.sol";

interface IStableSwap3Pool is ICurvePool {
    function add_liquidity(uint256[3] calldata amounts, uint256 min_lp) external;
}
