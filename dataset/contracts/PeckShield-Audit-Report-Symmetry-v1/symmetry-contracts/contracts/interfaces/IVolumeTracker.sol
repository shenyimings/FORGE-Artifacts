// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IVolumeTracker {
    /*=== struct ===*/

    struct Tier {
        uint requirement;
        uint rebateRatio;
    }

    enum RevertReason {
        EMPTY,
        DRAWED,
        NOT_ISSUED,
        HASH_UNAVAILABLE
    }

    /*=== events ===*/

    event WeeklyVolumeUpdated(address account, uint ts, uint volume);
    event WeeklyCouponClaimed(address account, uint ts);

    /*=== function ===*/

    function claimLuckyCoupon() external;

    function claimWeeklyTradingFeeCoupon(uint[] memory _t) external returns (uint);

    function coupon() external view returns (address);

    function drawLuckyNumber(uint _t) external;

    function drawLuckyNumberByAnnouncer(uint _t, bytes32 h1, bytes32 h2, bytes32 h3) external;

    function logTrade(address _account, uint _volume) external;

    function market() external view returns (address);

    function rebateTiers(uint) external view returns (uint requirement, uint rebateRatio);

    function settings() external view returns (address);

    function userDailyVolume(address, uint) external view returns (uint);

    function userWeeklyVolume(address, uint) external view returns (uint);
}
