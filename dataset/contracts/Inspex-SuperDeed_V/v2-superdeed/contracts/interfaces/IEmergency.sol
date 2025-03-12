// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

interface IEmergency {
   function approveEmergencyAssetWithdraw(uint maxAmount) external;
   function daoMultiSigEmergencyWithdraw(address tokenAddress, address to, uint amount) external;
}
