// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { LibPoolConfigV1 } from "../libraries/LibPoolConfigV1.sol";
import { LinkedList } from "../../../libraries/LinkedList.sol";

contract PoolConfigInitializer02 {
  using LinkedList for LinkedList.List;

  function initialize(
    address treasury,
    uint64 fundingInterval,
    uint64 mintBurnFeeBps,
    uint64 taxBps,
    uint64 stableBorrowingRateFactor,
    uint64 borrowingRateFactor,
    uint64 fundingRateFactor,
    uint256 liquidationFeeUsd
  ) external {
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    poolConfigDs.allowTokens.init();

    poolConfigDs.treasury = treasury;

    poolConfigDs.fundingInterval = fundingInterval;
    poolConfigDs.mintBurnFeeBps = mintBurnFeeBps;
    poolConfigDs.taxBps = taxBps;
    poolConfigDs.stableBorrowingRateFactor = stableBorrowingRateFactor;
    poolConfigDs.borrowingRateFactor = borrowingRateFactor;
    poolConfigDs.fundingRateFactor = fundingRateFactor;
    poolConfigDs.liquidationFeeUsd = liquidationFeeUsd;

    poolConfigDs.maxLeverage = 70 * 10000;

    poolConfigDs.isDynamicFeeEnable = true;
    poolConfigDs.isSwapEnable = true;
    poolConfigDs.isLeverageEnable = true;

    poolConfigDs.stableSwapFeeBps = 4;
    poolConfigDs.swapFeeBps = 30;
    poolConfigDs.positionFeeBps = 9;
    poolConfigDs.flashLoanFeeBps = 8;
  }
}
