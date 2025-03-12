// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface ICNCLockerV2Wrapper {
    function balanceOf(address account) external view returns (uint256);

    function totalVoteBoost(address account) external view returns (uint256);
}
