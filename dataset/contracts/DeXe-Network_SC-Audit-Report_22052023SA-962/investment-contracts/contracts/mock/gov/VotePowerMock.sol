// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../interfaces/gov/voting/IVotePower.sol";

import "../../core/Globals.sol";

contract VotePowerMock is IVotePower, OwnableUpgradeable {
    uint256 private _power;

    function __VotePower_init() external initializer {
        __Ownable_init();
    }

    function setPower(uint256 power) external {
        _power = power;
    }

    function transformVotes(
        address,
        uint256 votes
    ) external pure override returns (uint256 resultingVotes) {
        return votes * votes;
    }

    function transformVotesFull(
        address,
        uint256 votes,
        uint256,
        uint256,
        uint256
    ) external pure override returns (uint256 resultingVotes) {
        return votes * votes;
    }

    function getVotesRatio(address) external pure override returns (uint256 votesRatio) {
        return PRECISION;
    }
}
