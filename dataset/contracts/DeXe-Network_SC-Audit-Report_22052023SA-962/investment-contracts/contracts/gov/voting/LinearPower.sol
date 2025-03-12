// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../interfaces/gov/voting/IVotePower.sol";

import "../../core/Globals.sol";

/// @dev has to be ownable for compatibility reasons
contract LinearPower is IVotePower, OwnableUpgradeable {
    function __LinearPower_init() external initializer {
        __Ownable_init();
    }

    function transformVotes(
        address,
        uint256 votes
    ) external pure override returns (uint256 resultingVotes) {
        return votes;
    }

    function transformVotesFull(
        address,
        uint256 votes,
        uint256,
        uint256,
        uint256
    ) external pure override returns (uint256 resultingVotes) {
        return votes;
    }

    function getVotesRatio(address) external pure override returns (uint256 votesRatio) {
        return PRECISION;
    }
}
