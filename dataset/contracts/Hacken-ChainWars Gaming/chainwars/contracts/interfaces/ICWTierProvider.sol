// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface ICWTierProvider {
    function getTier(address account, uint256 holding) external view returns (uint8);
}
