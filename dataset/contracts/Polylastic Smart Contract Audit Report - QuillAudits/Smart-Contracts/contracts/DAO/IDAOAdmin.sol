// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IDAOAdmin {
    /**
     * @dev add a users to the whitelist
     * @param accounts array with adresses
     */
    function addAdmins(address[] memory accounts) external;

    /**
     * @dev removing a users from the whitelist
     * @param accounts array with adresses
     */
    function removeAdmins(address[] memory accounts) external;

    /**
     *@dev set the duration of the vote
     */
    function setPeriodDuration(uint256 debatingPeriodDuration) external;

    /**
     * @dev set the minimum percentage of votes from the total number
     * of tokens to consider the vote successful
     */
    function setMinimumQuorumPercent(uint256 minimumQuorum) external;

    /**
     * @dev adding a new poll
     * @param startTime voting start time
     */
    function addPoll(uint256 startTime) external;

    function isWhiteList(address account) external view returns (bool);
}
