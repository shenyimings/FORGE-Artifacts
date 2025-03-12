// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ISYMRate {
    /*=== struct ===*/

    struct Rate {
        uint startTime;
        uint rate;
    }

    /*=== function ===*/

    function getSum(uint start, uint end) external view returns (uint sum);

    function rates(uint) external view returns (uint startTime, uint rate);
}
