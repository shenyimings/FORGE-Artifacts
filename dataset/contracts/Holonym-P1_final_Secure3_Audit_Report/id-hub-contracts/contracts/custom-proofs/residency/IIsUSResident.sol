// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
interface IIsUSResident {
   function usResidency(address) external view returns (bool);
}