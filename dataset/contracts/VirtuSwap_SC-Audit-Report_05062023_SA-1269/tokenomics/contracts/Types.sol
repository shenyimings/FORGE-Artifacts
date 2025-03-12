// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {SD59x18} from "@prb/math/src/SD59x18.sol";

struct VrswStake {
    // start timestamp of the current position
    uint128 startTs;
    // lock duration of the current posisiton (0 if position is not locked)
    uint128 lockDuration;
    // discount factor for the current position equals exp(-r * stakeTime)
    // used in formula (3) in Virtuswap Tokenomics Whitepaper
    SD59x18 discountFactor;
    // amount of tokens staked for current position
    SD59x18 amount;
}

struct LpStake {
    // address of staked lpToken
    address lpToken;
    // amount of lpTokens staked
    SD59x18 amount;
}
