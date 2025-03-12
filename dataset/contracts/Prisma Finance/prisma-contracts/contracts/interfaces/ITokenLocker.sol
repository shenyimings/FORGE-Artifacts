// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface ITokenLocker {
    struct LockData {
        uint amount;
        uint weeksToUnlock;
    }

    function lock(address _account, uint256 _amount, uint256 _weeks) external returns (bool);

    function getAccountActiveLocks(
        address account,
        uint minWeeks
    ) external view returns (LockData[] memory lockData, uint frozenAmount);

    function getAccountWeightAt(address account, uint week) external view returns (uint256);

    function getTotalWeightAt(uint week) external view returns (uint256);

    function lockToTokenRatio() external view returns (uint256);
}
