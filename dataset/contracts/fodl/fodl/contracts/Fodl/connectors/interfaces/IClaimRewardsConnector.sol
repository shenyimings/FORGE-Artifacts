// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IClaimRewardsConnector {
    function claimRewards() external returns (address, uint256);
}
