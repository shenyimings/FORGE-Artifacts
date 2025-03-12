// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

interface IFeeModel {
  function getFeeRate(
    uint256 startBlock,
    uint256 currentBlock,
    uint256 endBlock
  ) external view returns (uint256);
}
