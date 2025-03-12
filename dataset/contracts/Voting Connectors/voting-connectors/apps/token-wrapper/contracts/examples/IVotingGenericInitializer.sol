/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 */

pragma solidity 0.4.24;

import "@aragon/os/contracts/lib/token/ERC20.sol";

import "@aragonone/voting-connectors-contract-utils/contracts/interfaces/IERC20WithCheckpointing.sol";


contract IVotingGenericInitializer {
    function initialize(IERC20WithCheckpointing _token, uint64 _supportRequiredPct, uint64 _minAcceptQuorumPct, uint64 _voteTime) external;
}
