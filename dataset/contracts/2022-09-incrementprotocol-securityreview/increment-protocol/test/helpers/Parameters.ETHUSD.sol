// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

library ETHUSD {
    /* Perpetual params */
    uint256 constant riskWeight = 3 ether;
    uint256 constant maxLiquidityProvided = 1_0000_000 ether;
    uint256 constant twapFrequency = 15 minutes;
    int256 constant sensitivity = 1e18;
    uint256 constant maxBlockTradeAmount = 100_000 ether;
    int256 constant insuranceFee = 0.001 ether;
    int256 constant lpDebtCoef = 3 ether;
    uint256 constant lockPeriod = 1 hours;

    /* vBase params */
    uint256 constant heartBeat = 25 hours;
    uint256 constant gracePeriod = 5 minutes;

    /* Curve params */
    uint256 constant A = 80000;
    uint256 constant gamma = 21e12;
    uint256 constant mid_fee = 5000000;
    uint256 constant out_fee = 50000000;
    uint256 constant allowed_extra_profit = 2e13;
    uint256 constant fee_gamma = 5e14;
    uint256 constant adjustment_step = 49e13;
    uint256 constant admin_fee = 0;
    uint256 constant ma_half_time = 600;
}
