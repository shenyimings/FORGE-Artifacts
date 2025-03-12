// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface I_MGH_VESTING_INITIATOR {
    function stakeableBalance() external view returns(uint256);
}