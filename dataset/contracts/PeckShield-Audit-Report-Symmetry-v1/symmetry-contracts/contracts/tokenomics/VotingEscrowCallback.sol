// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

abstract contract VotingEscrowCallback {
    function syncWithVotingEscrow(address _account) external virtual {}
}
