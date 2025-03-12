// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IDAOCommunity {
    /**
     * @dev set the duration of the vote
     */
    function changePeriodDuration(uint256 debatingPeriodDuration) external;

    /**
     * @dev set the minimum percentage of votes from the total number
     * of tokens to consider the vote successful
     */
    function changeMinimumQuorumPercent(uint256 minimumQuorum) external;
}
