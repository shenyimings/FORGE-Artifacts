// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/IGovPool.sol";

interface IVotePower {
    /// @notice The function for transforming token and nft power to voting power
    /// @param voter the voter address
    /// @param votes the total token and nft power
    /// @return resultingVotes voting power
    function transformVotes(
        address voter,
        uint256 votes
    ) external view returns (uint256 resultingVotes);

    /// @notice The function for transforming token and nft power to voting power
    /// @param voter the voter address
    /// @param votes the total token and nft power
    /// @param personalPower the user's total personal power
    /// @param micropoolPower the user's total micropool power
    /// @param treasuryPower the user's total treasury power
    /// @return resultingVotes voting power
    function transformVotesFull(
        address voter,
        uint256 votes,
        uint256 personalPower,
        uint256 micropoolPower,
        uint256 treasuryPower
    ) external view returns (uint256 resultingVotes);

    /// @notice The function for getting voting coefficient
    /// @param voter the address of the voter
    /// @return votesRatio the ration with 25 decimals precision
    function getVotesRatio(address voter) external view returns (uint256 votesRatio);
}
