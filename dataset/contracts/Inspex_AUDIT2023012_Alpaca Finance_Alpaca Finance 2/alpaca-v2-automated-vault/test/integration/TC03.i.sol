// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../fixtures/PancakeV3WorkerExecutorBankIntegrationFixture.f.sol";

// Contract under test
// - PCSV3Executor01
// - PancakeV3Worker

// Scenario
// current tick = -57864, tick spacing = 10
// 1) vault manager open position
// price move out of range
// 2) vault manager borrow other side
// 3) vault manager change tick
//   a) close out of range position
//   b) open position with new in range tick using old liquidity + borrowed to make it balance

contract TC03 is PancakeV3WorkerExecutorBankIntegrationFixture {
  constructor() PancakeV3WorkerExecutorBankIntegrationFixture() { }

  function _swapExactInput(address tokenIn_, address tokenOut_, uint24 fee_, uint256 swapAmount) internal {
    deal(tokenIn_, address(this), swapAmount);
    // Approve router to spend token1
    IERC20(tokenIn_).approve(address(pancakeV3Router), swapAmount);
    // Swap
    pancakeV3Router.exactInputSingle(
      IPancakeV3Router.ExactInputSingleParams({
        tokenIn: tokenIn_,
        tokenOut: tokenOut_,
        fee: fee_,
        recipient: address(this),
        amountIn: swapAmount,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      })
    );
  }

  function test_TC03_PositionOutOfRange_BorrowMore_ChangeTick() public {
    vm.startPrank(mockVaultManager);

    // Mock vault manager executor in scope
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(address(executor)));
    // Set worker and vault token for executor
    executor.setExecutionScope(address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken));

    //
    // Step 1: vault manager open out of range position
    //
    // Prepare undeployed funds for worker
    deal(address(usdt), address(workerUSDTWBNB), 1 ether);
    deal(address(wbnb), address(workerUSDTWBNB), 1 ether);
    // Open position
    executor.openPosition(-57870, -57860, 1 ether, 1 ether);

    // Move price out of range
    changePrank(address(this));
    _swapExactInput(address(usdt), address(wbnb), 500, 300000 ether);
    changePrank(mockVaultManager);

    // // Calculate amount to borrow, keep for reference
    // executor.closePosition();
    // (uint256 amountIn, uint256 amountOut, bool zeroForOne) = zapV3.calc(
    //   IZapV3.CalcParams({
    //     pool: address(pancakeV3USDTWBNBPool),
    //     amountIn0: usdt.balanceOf(address(workerUSDTWBNB)),
    //     amountIn1: wbnb.balanceOf(address(workerUSDTWBNB)),
    //     tickLower: -57900,
    //     tickUpper: -57700
    //   })
    // );
    // console.log(usdt.balanceOf(address(workerUSDTWBNB)));
    // console.log(wbnb.balanceOf(address(workerUSDTWBNB)));
    // console.log(amountIn);
    // console.log(amountOut);
    // console.log(zeroForOne);

    //
    // Step 2: vault manager borrow other side
    //
    // Currently position only have 326805033887382592390 USDT
    // We have to borrow 222236699054462729 WBNB to make it balance when add to -57900, -57700 range
    deal(address(wbnb), address(mockMoneyMarket), 222236699054462729);
    executor.borrow(address(wbnb), 222236699054462729);

    //
    // Step 3a: vault manager close out of range position
    //
    executor.closePosition();

    //
    // Step 3b: vault manager open position with new in range tick using old liquidity + borrowed to make it balance
    //
    executor.openPosition(-57900, -57700, 326805033887382592390, 222236699054462729);
  }
}
