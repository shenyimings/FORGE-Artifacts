// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IUpdatable {
    /**
     * @return Last update block number.
     */
    function lastUpdateBlockNumber() external view returns (uint256);
}
