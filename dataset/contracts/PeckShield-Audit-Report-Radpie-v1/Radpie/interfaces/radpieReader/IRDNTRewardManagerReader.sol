// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRDNTRewardManagerReader {

    function nextVestingTime() external view returns(uint256);

    function entitledRDNTByReceipt(address _account, address _receipt) external view returns (uint256);

    function esRDNT() external view returns(address);
}