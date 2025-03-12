// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

interface FeeManager {
    function feeAddress() external view returns (address);
    function feeRateBPS(address user, uint256 _depositAmount, uint256 _debt) external view returns (uint256);
}
