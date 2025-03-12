// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ISpoolDoHardWork {
    /* ========== EVENTS ========== */

    event DoHardWorkStrategyCompleted(address indexed strat, uint256 indexed index);
    event DoHardWorkCompleted(uint256 indexed index);
}
