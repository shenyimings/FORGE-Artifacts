// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../interfaces/IVotingWeightSource.sol";

interface IChangeGovernance {
    function changeGovernance(address newGovernance) external;
    function confirmChanged() external;
}

interface ITimeLock {
    function updateLockPeriod(uint256 newLockPeriod) external;
}

contract GovernanceTester {
    uint256 public constant votingPeriod = 60 * 60 * 24 * 3; // 3 days

    function readWeightKAP(IVotingWeightSource kapStaking, address voter)
        external
        view
        returns (uint256)
    {
        return kapStaking.votingWeight(voter);
    }

    function changeGovernance(address governanceRegistry, address newGovernance) external {
        IChangeGovernance(governanceRegistry).changeGovernance(newGovernance);
    }

    function confirmChanged(address governanceRegistry) external
    {
        IChangeGovernance(governanceRegistry).confirmChanged();
    }

    function changeTimeLockPeriod(address timeLock, uint256 newLockPeriod) external {
        ITimeLock(timeLock).updateLockPeriod(newLockPeriod);
    }
}
