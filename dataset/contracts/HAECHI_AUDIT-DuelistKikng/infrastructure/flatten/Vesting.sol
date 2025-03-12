// Root file: contracts/operators/Vesting.sol

// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;

contract Vesting {
  struct Term {
    address genesis;
    address token;
    address beneficiary;
    uint256 unlockAtTGE;
    uint256 cliffDuration;
    uint256 startCliff;
    uint256 vestingDuration;
    uint256 releaseType;
    uint256 amount;
  }

  struct Schedule {
    address genesis;
    address beneficiary;
    uint256 startVesting;
    uint256 totalBlocks;
    uint256 consumedBlocks;
    uint256 releaseType;
    uint256 unlockAmountPerBlock;
    uint256 remain;
  }
}
