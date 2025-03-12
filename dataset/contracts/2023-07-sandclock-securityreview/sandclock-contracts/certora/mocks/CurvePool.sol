// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "../../src/interfaces/curve/ICurvePool.sol";
import "./IStETH.sol";

contract CurvePool is ICurvePool {

    IStETH public stEth;

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable override returns (uint256) {
        if (i == 0) {
            require(msg.value == dx);
            stEth.transfer(msg.sender, min_dy + 0.01e18);
        } else {
            require(msg.value == 0);
            stEth.transferFrom(msg.sender, address(this), dx);
            payable(msg.sender).transfer(min_dy + 0.01e18);
        }
        return min_dy + 0.01e18;
    }
}