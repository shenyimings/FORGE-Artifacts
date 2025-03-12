// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IRecommendation {
    struct ReferralInfo {
        uint256 bindAt;
        address referrer;
    }

    function isReferrer(address referrer) external view returns (bool);

    function getReferralInfo(address referral) external view returns (bool exists, ReferralInfo memory referralInfo);
}