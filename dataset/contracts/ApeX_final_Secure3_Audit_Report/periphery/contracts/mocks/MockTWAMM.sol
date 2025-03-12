// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

contract MockTWAMM {
    uint256 public reserve0_;
    uint256 public reserve1_;

    function obtainReserves(address token0, address token1)
        external view
        returns (uint256 reserve0, uint256 reserve1) {
            reserve0 = reserve0_;
            reserve1 = reserve1_;
    }

    function setReserves(uint256 reserve0, uint256 reserve1) external {
        reserve0_ = reserve0;
        reserve1_ = reserve1;
    }
}