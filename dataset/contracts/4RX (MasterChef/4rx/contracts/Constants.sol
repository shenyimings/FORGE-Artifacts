// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;


contract Constants {
    uint public constant MAX_CONTRACT_REWARD_BP = 37455; // 374.55%

    uint public constant LP_FEE_BP = 500; // 5%
    uint public constant REF_COMMISSION_BP = 800; // 8%

    // Ref and sponsor pools
    uint public constant REF_POOL_FEE_BP = 50; // 0.5%, goes to ref pool from each deposit
    uint public constant SPONSOR_POOL_FEE_BP = 50; // 0.5%, goes to sponsor pool from each deposit

    uint public constant EXIT_PENALTY_BP = 5000; // 50%, deduct from user's initial deposit on exit

    // Contract bonus
    uint public constant MAX_CONTRACT_BONUS_BP = 300; // maximum bonus a user can get 3%
    uint public constant CONTRACT_BONUS_UNIT = 250;    // For each 250 token balance of contract, gives
    uint public constant CONTRACT_BONUS_PER_UNIT_BP = 1; // 0.01% extra interest

    // Hold bonus
    uint public constant MAX_HOLD_BONUS_BP = 100; // Maximum 1% hold bonus
    uint public constant HOLD_BONUS_UNIT = 43200; // 12 hours
    uint public constant HOLD_BONUS_PER_UNIT_BP = 2; // 0.02% hold bonus for each 12 hours of hold

    uint public constant REWARD_THRESHOLD_BP = 300; // User will only get hold bonus if his rewards are more then 3% of his deposit

    uint public constant MAX_WITHDRAWAL_OVER_REWARD_THRESHOLD_BP = 300; // Max daily withdrawal limit if user is above REWARD_THRESHOLD_BP

    uint public constant DEV_FEE_BP = 500; // 5%
}
