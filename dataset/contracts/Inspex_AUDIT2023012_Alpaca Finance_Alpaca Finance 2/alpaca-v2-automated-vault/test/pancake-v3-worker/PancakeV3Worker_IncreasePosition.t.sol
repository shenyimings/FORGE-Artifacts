// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// fixtures
import "test/fixtures/PancakeV3WorkerFixture.f.sol";

contract PancakeV3WorkerIncreasePositionTest is PancakeV3WorkerFixture {
  using stdStorage for StdStorage;

  constructor() PancakeV3WorkerFixture() { }

  function testRevert_OpenPosition_NotExecutorInScope() public {
    vm.prank(address(1234));
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 1 ether, 1 ether);
  }

  function testRevert_OpenPosition_PositionExist() public {
    // overwrite `nftTokenId` storage to some address
    stdstore.target(address(worker)).sig("nftTokenId()").checked_write(address(1234));

    vm.prank(IN_SCOPE_EXECUTOR);
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_PositionExist.selector);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 1 ether, 1 ether);
  }

  // TODO: out of range
  function testCorrectness_OpenPosition_InRange() public {
    assertEq(worker.nftTokenId(), 0);

    uint256 amountIn0 = 1 ether;
    uint256 amountIn1 = 1 ether;

    deal(address(token0), address(worker), amountIn0);
    deal(address(token1), address(worker), amountIn1);

    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, amountIn0, amountIn1);

    // Worker assertions
    // - token0 remain less than DUST
    // - token1 remain less than DUST
    // - state `nftTokenId` should be set
    // - state `posTickLower` should be set to specified tick
    // - state `posTickUpper` should be set to specified tick
    assertLt(token0.balanceOf(address(worker)), DUST);
    assertLt(token1.balanceOf(address(worker)), DUST);
    assertEq(worker.nftTokenId(), 46528);
    assertEq(worker.posTickLower(), TICK_LOWER);
    assertEq(worker.posTickUpper(), TICK_UPPER);

    // External assertions
    // - nft should be staked with masterChef
    // - staked nft should have tick same as worker
    IPancakeV3MasterChef.UserPositionInfo memory userInfo = pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());
    assertEq(userInfo.user, address(worker));
    assertEq(userInfo.tickLower, worker.posTickLower());
    assertEq(userInfo.tickUpper, worker.posTickUpper());
  }

  function testRevert_IncreasePosition_NotExecutorInScope() public {
    vm.prank(address(1234));
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
    worker.increasePosition(1 ether, 1 ether);
  }

  function testRevert_IncreasePosition_PositionNotExist() public {
    // overwrite `nftTokenId` storage to zero
    stdstore.target(address(worker)).sig("nftTokenId()").checked_write(address(0));

    vm.prank(IN_SCOPE_EXECUTOR);
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_PositionNotExist.selector);
    worker.increasePosition(1 ether, 1 ether);
  }

  // TODO: out of range
  function testCorrectness_IncreasePosition_InRange() public {
    // Open position
    deal(address(token0), address(worker), 1 ether);
    deal(address(token1), address(worker), 1 ether);
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 1 ether, 1 ether);

    uint256 amountIn0 = 1 ether;
    uint256 amountIn1 = 1 ether;

    IPancakeV3MasterChef.UserPositionInfo memory userInfoBefore =
      pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());

    deal(address(token0), address(worker), amountIn0);
    deal(address(token1), address(worker), amountIn1);
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.increasePosition(amountIn0, amountIn1);

    // External assertions
    // - staked position liquidity should be increased
    IPancakeV3MasterChef.UserPositionInfo memory userInfoAfter =
      pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());
    assertGt(userInfoAfter.liquidity, userInfoBefore.liquidity);

    // Worker invariants
    // - state `nftTokenId` should remain the same
    // - state `posTickLower` should remain the same
    // - state `posTickUpper` should remain the same
    assertEq(worker.nftTokenId(), 46528);
    assertEq(worker.posTickLower(), TICK_LOWER);
    assertEq(worker.posTickUpper(), TICK_UPPER);
  }
}

// function testCorrectness_IncreaseLiquidity_InRange_Subsequently() public {
//     // Assert
//     // - Worker's tokenId must be 0
//     assertEq(worker.nftTokenId(), 0, "tokenId must be 0");

//     // Increase position by 10_000 TKN0 and 1 TKN1
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 1 ether));
//     worker.openPosition()

//     // Asserts:
//     // - token0 and token1 must left in worker less than DUST
//     // - tokenId must be 46528
//     assertLt(token0.balanceOf(address(worker)), DUST, "token0 must left in worker less than DUST");
//     assertLt(token1.balanceOf(address(worker)), DUST, "token1 must left in worker less than DUST");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");

//     CommonV3ImportantPositionInfo memory positionInfo = _getImportantPositionInfo(46528);
//     assertEq(positionInfo.tickLower, TICK_LOWER, "tickLower must be TICK_LOWER");
//     assertEq(positionInfo.tickUpper, TICK_UPPER, "tickUpper must be TICK_UPPER");
//     assertEq(positionInfo.liquidity, 45904151499858308508910, "liquidity must be 45904151499858308508910");
//     assertEq(positionInfo.tokensOwed0, 0, "tokensOwed0 must be 0");
//     assertEq(positionInfo.tokensOwed1, 0, "tokensOwed1 must be 0");

//     // Increase position by 10_000 TKN0 and 25_000 TKN1 again
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 25_000 ether));

//     // Assert:
//     // - token0 and token1 must left in worker less than DUST
//     // - Worker's tokenId must be 46528
//     // - Worker's position's liquidity must be 20_000 TKN0 and 50_000 TKN1
//     assertLt(token0.balanceOf(address(worker)), DUST, "token0 must left in worker less than DUST");
//     assertLt(token1.balanceOf(address(worker)), DUST, "token1 must left in worker less than DUST");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 25902");

//     positionInfo = _getImportantPositionInfo(46528);
//     assertEq(positionInfo.tickLower, TICK_LOWER, "tickLower must be TICK_LOWER");
//     assertEq(positionInfo.tickUpper, TICK_UPPER, "tickUpper must be TICK_UPPER");
//     assertEq(positionInfo.liquidity, 36235370516829017460459509, "liquidity must be 36235370516829017460459509");
//     assertEq(positionInfo.tokensOwed0, 0, "tokensOwed0 must be 0");
//     assertEq(positionInfo.tokensOwed1, 3439773883040434, "tokensOwed1 must be 3439773883040434");
//   }

//   function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickMoreThanTickUpper_AfterSwappedStillOutOfRange() public {
//     // Swap so that pool's current tick goes beyond TICK_UPPER
//     _swapExactInput(address(token1), address(token0), poolFee, 5_500 ether);

//     // Asserts:
//     // - pool's current tick goes beyond TICK_UPPER
//     // - pool's position should be out of range
//     (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
//     assertGt(currTick, TICK_UPPER, "currTick must be more than TICK_UPPER");
//     assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

//     // Increase position by 10_000 USDT and 10 WBNB
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 10 ether));

//     // Assert:
//     // - token0 and token1 must NOT left in worker
//     // - Worker's tokenId must be 46528
//     assertEq(token0.balanceOf(address(worker)), 0, "worker's token0 must be 0");
//     assertEq(token1.balanceOf(address(worker)), 0, "worker's token1 must be 0");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
//   }

//   function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickMoreThanTickUpper_AfterSwappedInRange() public {
//     // Swap so that pool's current tick goes beyond TICK_UPPER
//     _swapExactInput(address(token1), address(token0), poolFee, 5_500 ether);

//     // Asserts:
//     // - pool's current tick goes beyond TICK_UPPER
//     // - pool's position should be out of range
//     (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
//     assertGt(currTick, TICK_UPPER, "currTick must be more than TICK_UPPER");
//     assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

//     // Increase position by 10_000 USDT and 0 WBNB
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 0));

//     // Assert:
//     // - token0 and token1 must less than DUST
//     // - Worker's tokenId must be 46528
//     assertLt(token0.balanceOf(address(worker)), DUST, "worker's token0 must be less than DUST");
//     assertLt(token1.balanceOf(address(worker)), DUST, "worker's token1 must be less than DUST");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
//   }

//   function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickLessThanTickLower_AfterSwappedStillOutOfRange() public {
//     // Swap so that pool's current tick goes below TICK_LOWER
//     _swapExactInput(address(token0), address(token1), poolFee, 2_000_000 ether);

//     // Asserts:
//     // - pool's current tick goes below TICK_LOWER
//     // - pool's position should be out of range
//     (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
//     assertTrue(currTick < TICK_LOWER, "currTick must be less than TICK_LOWER");
//     assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

//     // Increase position by 10_000 USDT and 1 WBNB
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 10 ether));

//     // Assert:
//     // - token0 and token1 must NOT left in worker
//     // - Worker's tokenId must be 46528
//     assertEq(token0.balanceOf(address(worker)), 0, "worker's token0 must be 0");
//     assertEq(token1.balanceOf(address(worker)), 0, "worker's token1 must be 0");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
//   }

//   function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickLessThanTickLower_AfterSwappedInRange() public {
//     // Swap so that pool's current tick goes below TICK_LOWER
//     _swapExactInput(address(token0), address(token1), poolFee, 2_000_000 ether);

//     // Asserts:
//     // - pool's current tick goes below TICK_LOWER
//     // - pool's position should be out of range
//     (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
//     assertTrue(currTick < TICK_LOWER, "currTick must be less than TICK_LOWER");
//     assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

//     // Increase position by 0 USDT and 300 WBNB
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(0 ether, 300 ether));

//     // Assert:
//     // - token0 and token1 must NOT left in worker
//     // - Worker's tokenId must be 46528
//     assertLt(token0.balanceOf(address(worker)), DUST, "worker's token0 must less than DUST");
//     assertLt(token1.balanceOf(address(worker)), DUST, "worker's token1 must less than DUST");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
//   }
