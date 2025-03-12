// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface ITierSystem {
    function getTierFromTo (address _account, uint256 _snapshotIdFrom, uint256 _snapshotIdTo) external view returns(uint256);
    function getTier (address _account) external view returns(uint256);
    function getAllocationPoint(uint256 _tier) external view returns(uint256);
}