// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title ITokenDistributor
 * @dev Interface for the TokenDistributor contract
 */
interface ITokenDistributor {
    /**
     * @dev Initializes the TokenDistributor contract.
     * @param _owner The address of the contract owner.
     * @param _poolName The name of the token distribution pool.
     * @param _startTime The start time of the distribution period.
     * @param _endTime The end time of the distribution period.
     * @param _distributionRate The distribution rate (percentage).
     * @param _periodLength The length of each distribution period (in seconds).
     */
    function initialize(
        address _owner,
        string memory _poolName,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _distributionRate,
        uint256 _periodLength
    ) external;
}
