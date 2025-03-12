// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {ButtonswapPair} from "../../src/ButtonswapPair.sol";
import {IERC20} from "buttonswap-core_@openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MockButtonswapPair is ButtonswapPair {
    function mockSetPoolsLast(uint112 _pool0Last, uint112 _pool1Last) public {
        pool0Last = _pool0Last;
        pool1Last = _pool1Last;
    }

    function mockGetLiquidityBalances(uint256 total0, uint256 total1)
        public
        view
        returns (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1)
    {
        if (total0 > 0 && total1 > 0) {
            LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
            pool0 = lb.pool0;
            pool1 = lb.pool1;
            reservoir0 = lb.reservoir0;
            reservoir1 = lb.reservoir1;
        }
    }
}
