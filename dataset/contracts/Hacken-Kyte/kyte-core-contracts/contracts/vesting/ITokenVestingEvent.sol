//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ITokenVestingEvent {
    event Released(uint256 amount);
    event Revoked();

    event AddVestingSchedule(
        bytes32 vestingScheduleId,
        address beneficiary,
        uint256 cliff,
        uint256 start,
        uint256 duration,
        uint256 slicePeriodSeconds,
        bool revocable,
        uint256 amountTotal,
        uint256 released,
        bool revoked,
        uint256 upFront
    );
    event RevokeVestingShedule(bytes32 vestingScheduleId);
    event UpfrontTokenTransfer(
        bytes32 vestingScheduleId,
        address beneficiary,
        uint256 amount
    );
    event ReleaseVestedToken(
        bytes32 vestingScheduleId,
        address beneficiary,
        uint256 amountReleased
    );
}
