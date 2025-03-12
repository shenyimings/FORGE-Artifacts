// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// fixtures
import "test/fixtures/PancakeV3WorkerFixture.f.sol";

contract PancakeV3WorkerTransferTest is PancakeV3WorkerFixture {
  using stdStorage for StdStorage;

  constructor() PancakeV3WorkerFixture() { }

  function testCorrectness_WhenTransferBackToExecutor_ShouldWork() external {
    uint256 _amount = 1 ether;
    deal(address(token1), address(worker), _amount);
    uint256 _workerToken1AmountBefore = token1.balanceOf(address(worker));
    uint256 _executorToken1AmountBefore = token1.balanceOf(IN_SCOPE_EXECUTOR);
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.transferToExecutor(address(token1), _amount);

    assertEq(token1.balanceOf(address(worker)), _workerToken1AmountBefore - _amount);
    assertEq(token1.balanceOf(address(IN_SCOPE_EXECUTOR)), _executorToken1AmountBefore + _amount);
  }

  function testRevert_WhenCallerIsNotExecutorInScope() external {
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
    worker.transferToExecutor(address(token1), 1 ether);
  }

  function testRevert_WhenTransferAmountIsZero() external {
    vm.prank(IN_SCOPE_EXECUTOR);
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_InvalidParams.selector);
    worker.transferToExecutor(address(token1), 0);
  }
}
