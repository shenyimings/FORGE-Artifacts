// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// fixtures
import "test/fixtures/PancakeV3WorkerFixture.f.sol";

contract PancakeV3WorkerDecreasePositionTest is PancakeV3WorkerFixture {
  using stdStorage for StdStorage;

  constructor() PancakeV3WorkerFixture() { }

  function testRevert_ClosePosition_NotExecutorInScope() public {
    vm.prank(address(1234));
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
    worker.closePosition();
  }

  function testRevert_ClosePosition_PositionNotExist() public {
    // overwrite `nftTokenId` storage to zero
    stdstore.target(address(worker)).sig("nftTokenId()").checked_write(address(0));

    vm.prank(IN_SCOPE_EXECUTOR);
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_PositionNotExist.selector);
    worker.closePosition();
  }

  // TODO: out of range
  function testCorrectness_ClosePosition_InRange() public {
    // Open position
    deal(address(token0), address(worker), 1 ether);
    deal(address(token1), address(worker), 1 ether);
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 1 ether, 1 ether);

    assertNotEq(worker.nftTokenId(), 0);

    uint256 token0Before = token0.balanceOf(address(worker));
    uint256 token1Before = token1.balanceOf(address(worker));

    vm.prank(IN_SCOPE_EXECUTOR);
    worker.closePosition();

    // Worker assertions
    // - token0 should increase
    // - token1 should increase
    // - state `nftTokenId` should be empty
    assertGt(token0.balanceOf(address(worker)), token0Before);
    assertGt(token1.balanceOf(address(worker)), token1Before);
    assertEq(worker.nftTokenId(), 0);

    // External assertions
    // - nft staked with masterChef should be gone
    IPancakeV3MasterChef.UserPositionInfo memory userInfo = pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());
    assertEq(userInfo.user, address(0));

    // Worker invariants
    // - state `posTickLower` should remain the same
    // - state `posTickUpper` should remain the same
    assertEq(worker.posTickLower(), TICK_LOWER);
    assertEq(worker.posTickUpper(), TICK_UPPER);
  }

  function testRevert_DecreasePosition_NotExecutorInScope() public {
    vm.prank(address(1234));
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
    worker.decreasePosition(1 ether);
  }

  function testRevert_DecreasePosition_PositionNotExist() public {
    // overwrite `nftTokenId` storage to zero
    stdstore.target(address(worker)).sig("nftTokenId()").checked_write(address(0));

    vm.prank(IN_SCOPE_EXECUTOR);
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_PositionNotExist.selector);
    worker.decreasePosition(1 ether);
  }

  // TODO: out of range
  function testCorrectness_DecreasePosition_InRange() public {
    // Open position
    deal(address(token0), address(worker), 1 ether);
    deal(address(token1), address(worker), 1 ether);
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 1 ether, 1 ether);

    assertNotEq(worker.nftTokenId(), 0);

    uint256 token0Before = token0.balanceOf(address(worker));
    uint256 token1Before = token1.balanceOf(address(worker));
    IPancakeV3MasterChef.UserPositionInfo memory userInfoBefore =
      pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());

    vm.prank(IN_SCOPE_EXECUTOR);
    worker.decreasePosition(1 ether);

    // Worker assertions
    // - token0 should increase
    // - token1 should increase
    assertGt(token0.balanceOf(address(worker)), token0Before);
    assertGt(token1.balanceOf(address(worker)), token1Before);

    // External assertions
    // - staked position liquidity should be decreased
    IPancakeV3MasterChef.UserPositionInfo memory userInfoAfter =
      pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());
    assertLt(userInfoAfter.liquidity, userInfoBefore.liquidity);

    // Worker invariants
    // - state `nftTokenId` should remain the same
    // - state `posTickLower` should remain the same
    // - state `posTickUpper` should remain the same
    assertEq(worker.nftTokenId(), 46528);
    assertEq(worker.posTickLower(), TICK_LOWER);
    assertEq(worker.posTickUpper(), TICK_UPPER);
  }
}
