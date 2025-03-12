// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IJamonShareVesting {
    function createVesting(
        address wallet_,
        uint256 jsNow_,
        uint256 jsEnd_
    ) external;
}
