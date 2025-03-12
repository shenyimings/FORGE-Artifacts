// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ICurvePool.sol";

interface IStableSwap2Pool is ICurvePool {
    function add_liquidity(uint256[2] calldata amounts, uint256 min_lp) external;
}
