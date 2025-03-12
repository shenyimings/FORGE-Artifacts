// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IStKDX {
    function getKdxBalanceAt(address _account, uint256 _snapShotId) external view returns (uint256);
    function getCurrentSnapshotId() external view returns (uint256);
}