// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeStrategy {
  function getExactFarmDepositFeeBPForDynaHolder(uint16 _defaultFeeBP, address _holder) external view returns (uint depositFeeRate);
  function getExactVaultDepositFeeBPForDynaHolder(uint16 _defaultFeeBP, address _holder) external view returns (uint depositFeeRate);
}
