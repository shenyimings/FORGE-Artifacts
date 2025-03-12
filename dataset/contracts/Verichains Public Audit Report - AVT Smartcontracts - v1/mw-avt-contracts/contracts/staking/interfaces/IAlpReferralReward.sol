// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IAlpReferralReward {
    function increaseAlpReferral(address _account, uint256 _baseAmount) external;

    function claimableReward(address referrer) external view returns (uint256);

    function claim() external returns (uint256);

    function claimForReferrer(address referrer) external returns (uint256);
}
