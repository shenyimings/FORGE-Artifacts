// SPDX-License-Identifier: BUSL1.1
pragma solidity 0.8.16;

import "../../../../lib/mock-contract/contracts/MockContract.sol";

contract MockFeeModel is MockContract {
  uint256 fee;

  function mockSetFee(uint256 _fee) external {
    fee = _fee;
  }

  function getFeeRate(
    uint256 startBlock,
    uint256 currentBlock,
    uint256 endBlock
  ) external view returns (uint256) {
    startBlock;
    currentBlock;
    endBlock;
    return fee;
  }
}
