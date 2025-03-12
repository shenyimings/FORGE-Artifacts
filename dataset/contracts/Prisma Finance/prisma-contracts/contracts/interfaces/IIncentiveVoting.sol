// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IIncentiveVoting {
    function unfreeze(address account, bool keepVote) external returns (bool);

    function getReceiverVotePct(uint id, uint week) external returns (uint);

    function idToReceiver(uint id) external view returns (uint);

    function registerNewReceiver() external returns (uint);
}
