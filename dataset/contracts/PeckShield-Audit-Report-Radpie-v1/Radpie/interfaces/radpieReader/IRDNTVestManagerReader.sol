// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct VestingSchedule {
    uint256 amount;
    uint256 endTime;
}    

interface IRDNTVestManagerReader {

    function nextVestingTime() external view returns(uint256);

    function getAllVestingInfo(
        address _user
    ) external view returns (VestingSchedule[] memory , uint256 totalRDNTRewards, uint256 totalVested, uint256 totalVesting);
}