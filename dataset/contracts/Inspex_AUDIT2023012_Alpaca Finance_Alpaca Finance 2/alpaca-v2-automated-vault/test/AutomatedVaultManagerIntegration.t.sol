// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.19;

// // interfaces
// import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
// import { IZapV3 } from "src/interfaces/IZapV3.sol";

// // fixtures
// import "test/fixtures/CompleteFixture.f.sol";

// contract AutomatedVaultManagerIntegrationTest is CompleteFixture {
//   constructor() CompleteFixture() { }

//   function setUp() public override {
//     vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);
//     super.setUp();

//     // whitelist manager and token
//     vm.startPrank(DEPLOYER);
//     vaultManager.setVaultManager(address(vaultToken), MANAGER, true);
//     vaultManager.setAllowToken(address(vaultToken), address(wbnb), true);
//     vaultManager.setAllowToken(address(vaultToken), address(usdt), true);
//     vm.stopPrank();
//   }

//   function testCorrectness_Deposit() public {
//     uint256 wbnbIn = 1 ether;
//     uint256 usdtIn = 2 ether;

//     deal(address(wbnb), address(moneyMarket), wbnbIn);
//     deal(address(usdt), address(moneyMarket), usdtIn);

//     deal(address(wbnb), address(this), wbnbIn);
//     wbnb.approve(address(vaultManager), type(uint256).max);
//     deal(address(usdt), address(this), usdtIn);
//     usdt.approve(address(vaultManager), type(uint256).max);

//     uint256 wbnbBefore = wbnb.balanceOf(address(this));
//     uint256 usdtBefore = usdt.balanceOf(address(this));

//     // Deposit
//     AutomatedVaultManager.TokenAmount[] memory params = new AutomatedVaultManager.TokenAmount[](2);
//     params[0] = AutomatedVaultManager.TokenAmount({ token: address(wbnb), amount: wbnbIn });
//     params[1] = AutomatedVaultManager.TokenAmount({ token: address(usdt), amount: usdtIn });

//     // Fail case
//     // Vault manager assertions
//     // Should fail because of slippage
//     vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_TooLittleReceived()"));
//     vaultManager.deposit(address(vaultToken), params, 10000 ether);

//     // Executor calls assertions
//     // - call `onUpdate` twice
//     // - call `onDeposit` once
//     // - call `onWithdraw` once
//     vm.expectCall(address(pancakeV3Executor), abi.encodeWithSelector(IExecutor.onUpdate.selector), 1);
//     vm.expectCall(address(pancakeV3Executor), abi.encodeWithSelector(IExecutor.onDeposit.selector), 1);

//     // Success case
//     vaultManager.deposit(address(vaultToken), params, 0);

//     // Vault manager assertions
//     // - pull tokens from caller
//     // - mint shares based on equityChange
//     // - get token back as proportion of optimal swap output
//     assertEq(wbnbBefore - wbnb.balanceOf(address(this)), wbnbIn, "wbnb pulled");
//     assertEq(usdtBefore - usdt.balanceOf(address(this)), usdtIn, "usdt pulled");
//     // Calculate expected equity
//     (, int256 wbnbAnswer,,,) = wbnbFeed.latestRoundData();
//     (, int256 usdtAnswer,,,) = usdtFeed.latestRoundData();
//     uint256 expectedEquity = wbnbIn * uint256(wbnbAnswer) / 1e8 + usdtIn * uint256(usdtAnswer) / 1e8;
//     assertApproxEqRel(vaultToken.balanceOf(address(this)), expectedEquity, 1e12, "shares received");

//     // Withdraw
//     // Fail case
//     // Vault manager assertions
//     // Should fail because of slippage
//     // AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](1);
//     // minAmountOuts[0] = AutomatedVaultManager.TokenAmount({ token: address(wbnb), amount: 10000 ether });
//     // vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_ExceedSlippage.selector);
//     // vaultManager.withdraw(address(vaultToken), vaultToken.balanceOf(address(this)), minAmountOuts);
//   }

//   // function testCorrectness_SimpleDepositWithdraw_EmptyVault() public {
//   //   uint256 wbnbIn = 1 ether;
//   //   uint256 usdtIn = 2 ether;

//   //   deal(address(wbnb), address(moneyMarket), wbnbIn);
//   //   deal(address(usdt), address(moneyMarket), usdtIn);

//   //   deal(address(wbnb), address(this), wbnbIn);
//   //   wbnb.approve(address(vaultManager), type(uint256).max);
//   //   deal(address(usdt), address(this), usdtIn);
//   //   usdt.approve(address(vaultManager), type(uint256).max);

//   //   // Calculated expected equity
//   //   // * 2 each to mimic simple deposit borrowing
//   //   uint256 expectedEquity;
//   //   uint256 expectedAddLiquidityWBNB;
//   //   uint256 expectedAddLiquidityUSDT;
//   //   {
//   //     (uint256 swapAmount,, bool zeroForOne) = zapV3.calc(
//   //       IZapV3.CalcParams({
//   //         pool: address(pancakeV3Worker.pool()),
//   //         amountIn0: usdtIn * 2,
//   //         amountIn1: wbnbIn * 2,
//   //         tickLower: TICK_LOWER,
//   //         tickUpper: TICK_UPPER
//   //       })
//   //     );
//   //     (uint256 amountOut,,,) = pancakeV3Quoter.quoteExactInputSingle(
//   //       IPancakeV3QuoterV2.QuoteExactInputSingleParams({
//   //         tokenIn: zeroForOne ? address(usdt) : address(wbnb),
//   //         tokenOut: zeroForOne ? address(wbnb) : address(usdt),
//   //         amountIn: swapAmount,
//   //         fee: pancakeV3Worker.poolFee(),
//   //         sqrtPriceLimitX96: 0
//   //       })
//   //     );
//   //     expectedAddLiquidityWBNB = wbnbIn * 2;
//   //     expectedAddLiquidityUSDT = usdtIn * 2;
//   //     if (zeroForOne) {
//   //       expectedAddLiquidityWBNB += amountOut;
//   //       expectedAddLiquidityUSDT -= swapAmount;
//   //     } else {
//   //       expectedAddLiquidityUSDT += amountOut;
//   //       expectedAddLiquidityWBNB -= swapAmount;
//   //     }
//   //     (, int256 wbnbAnswer,,,) = wbnbFeed.latestRoundData();
//   //     (, int256 usdtAnswer,,,) = usdtFeed.latestRoundData();
//   //     // subtract amountIn to mimic equity = postionVal - debtVal
//   //     int256 wbnbEquity = int256(
//   //       (int256(expectedAddLiquidityWBNB) - int256(wbnbIn)) * int256(10 ** (18 - wbnb.decimals())) * wbnbAnswer
//   //     ) / int256(10 ** wbnbFeed.decimals());
//   //     int256 usdtEquity = int256(
//   //       (int256(expectedAddLiquidityUSDT) - int256(usdtIn)) * int256(10 ** (18 - usdt.decimals())) * usdtAnswer
//   //     ) / int256(10 ** usdtFeed.decimals());
//   //     expectedEquity = uint256(wbnbEquity + usdtEquity);
//   //   }

//   //   uint256 wbnbBefore = wbnb.balanceOf(address(this));
//   //   uint256 usdtBefore = usdt.balanceOf(address(this));

//   //   // Assertions
//   //   // - pull tokens from caller
//   //   // - call updateExecutor twice (deposit, withdraw)
//   //   // - call depositExecutor
//   //   // - call withdrawExecutor
//   //   // - mint shares based on equityChange
//   //   // - get token back as proportion of optimal swap output

//   //   vm.expectCall(address(pancakeV3Executor), abi.encodeWithSelector(IExecutor.onUpdate.selector), 2);
//   //   vm.expectCall(address(pancakeV3Executor), abi.encodeWithSelector(IExecutor.onDeposit.selector), 1);
//   //   vm.expectCall(address(pancakeV3Executor), abi.encodeWithSelector(IExecutor.onWithdraw.selector), 1);

//   //   AutomatedVaultManager.TokenAmount[] memory params = new AutomatedVaultManager.TokenAmount[](2);
//   //   params[0] = AutomatedVaultManager.TokenAmount({ token: address(wbnb), amount: wbnbIn });
//   //   params[1] = AutomatedVaultManager.TokenAmount({ token: address(usdt), amount: usdtIn });
//   //   vaultManager.deposit(address(vaultToken), params);

//   //   assertEq(wbnbBefore - wbnb.balanceOf(address(this)), wbnbIn, "wbnb pulled");
//   //   assertEq(usdtBefore - usdt.balanceOf(address(this)), usdtIn, "usdt pulled");
//   //   assertApproxEqRel(vaultToken.balanceOf(address(this)), expectedEquity, 1e12, "shares received");

//   //   wbnbBefore = wbnb.balanceOf(address(this));
//   //   usdtBefore = usdt.balanceOf(address(this));

//   //   // Withdraw without slippage check
//   //   AutomatedVaultManager.TokenAmount[] memory minAmountOuts = new AutomatedVaultManager.TokenAmount[](0);
//   //   vaultManager.withdraw(address(vaultToken), vaultToken.balanceOf(address(this)), minAmountOuts);

//   //   assertApproxEqRel(
//   //     wbnb.balanceOf(address(this)) - wbnbBefore, expectedAddLiquidityWBNB - wbnbIn, 1e12, "wbnb withdraw"
//   //   );
//   //   assertApproxEqRel(
//   //     usdt.balanceOf(address(this)) - usdtBefore, expectedAddLiquidityUSDT - usdtIn, 1e12, "usdt withdraw"
//   //   );
//   // }

//   // This fuzz still fail for case where there are 2 debt but optimal swap only result in 1 token so can't repay
//   // Will revisit when dealing with real withdraw executor
//   // function testForkFuzz_DepositWithdraw_EmptyVault(uint256 wbnbIn, uint256 usdtIn) public {
//   //   wbnbIn = bound(wbnbIn, 1e6, 1e21);
//   //   usdtIn = bound(usdtIn, 1e6, 1e21);

//   //   deal(address(wbnb), address(moneyMarket), wbnbIn);
//   //   deal(address(usdt), address(moneyMarket), usdtIn);

//   //   deal(address(wbnb), address(this), wbnbIn);
//   //   wbnb.approve(address(vaultManager), type(uint256).max);
//   //   deal(address(usdt), address(this), usdtIn);
//   //   usdt.approve(address(vaultManager), type(uint256).max);

//   //   // Calculated expected equity
//   //   // * 2 each to mimic simple deposit borrowing
//   //   uint256 expectedEquity;
//   //   uint256 expectedAddLiquidityWBNB;
//   //   uint256 expectedAddLiquidityUSDT;
//   //   {
//   //     (uint256 swapAmount,, bool zeroForOne) = zapV3.calc(
//   //       IZapV3.CalcParams({
//   //         pool: address(pancakeV3Worker.pool()),
//   //         amountIn0: usdtIn * 2,
//   //         amountIn1: wbnbIn * 2,
//   //         tickLower: TICK_LOWER,
//   //         tickUpper: TICK_UPPER
//   //       })
//   //     );
//   //     (uint256 amountOut,,,) = pancakeV3Quoter.quoteExactInputSingle(
//   //       IPancakeV3QuoterV2.QuoteExactInputSingleParams({
//   //         tokenIn: zeroForOne ? address(usdt) : address(wbnb),
//   //         tokenOut: zeroForOne ? address(wbnb) : address(usdt),
//   //         amountIn: swapAmount,
//   //         fee: pancakeV3Worker.poolFee(),
//   //         sqrtPriceLimitX96: 0
//   //       })
//   //     );
//   //     expectedAddLiquidityWBNB = wbnbIn * 2;
//   //     expectedAddLiquidityUSDT = usdtIn * 2;
//   //     if (zeroForOne) {
//   //       expectedAddLiquidityWBNB += amountOut;
//   //       expectedAddLiquidityUSDT -= swapAmount;
//   //     } else {
//   //       expectedAddLiquidityUSDT += amountOut;
//   //       expectedAddLiquidityWBNB -= swapAmount;
//   //     }
//   //     (, int256 wbnbAnswer,,,) = wbnbFeed.latestRoundData();
//   //     (, int256 usdtAnswer,,,) = usdtFeed.latestRoundData();
//   //     // subtract amountIn to mimic equity = postionVal - debtVal
//   //     int256 wbnbEquity = int256(
//   //       (int256(expectedAddLiquidityWBNB) - int256(wbnbIn)) * int256(10 ** (18 - wbnb.decimals())) * wbnbAnswer
//   //     ) / int256(10 ** wbnbFeed.decimals());
//   //     int256 usdtEquity = int256(
//   //       (int256(expectedAddLiquidityUSDT) - int256(usdtIn)) * int256(10 ** (18 - usdt.decimals())) * usdtAnswer
//   //     ) / int256(10 ** usdtFeed.decimals());
//   //     expectedEquity = uint256(wbnbEquity + usdtEquity);
//   //   }

//   //   uint256 wbnbBefore = wbnb.balanceOf(address(this));
//   //   uint256 usdtBefore = usdt.balanceOf(address(this));

//   //   // Assertions
//   //   // - pull tokens from caller
//   //   // - call updateExecutor twice (deposit, withdraw)
//   //   // - call depositExecutor
//   //   // - call withdrawExecutor
//   //   // - mint shares based on equityChange
//   //   // - get token back as proportion of optimal swap output

//   //   vm.expectCall(address(pancakeV3Executor), abi.encodeWithSelector(IExecutor.onUpdate.selector), 2);
//   //   vm.expectCall(address(pancakeV3Executor), abi.encodeWithSelector(IExecutor.onDeposit.selector), 1);
//   //   vm.expectCall(address(pancakeV3Executor), abi.encodeWithSelector(IExecutor.onWithdraw.selector), 1);

//   //   AutomatedVaultManager.TokenAmount[] memory params = new AutomatedVaultManager.TokenAmount[](2);
//   //   params[0] = AutomatedVaultManager.TokenAmount({ token: address(wbnb), amount: wbnbIn });
//   //   params[1] = AutomatedVaultManager.TokenAmount({ token: address(usdt), amount: usdtIn });
//   //   vaultManager.deposit(address(vaultToken), params);

//   //   assertEq(wbnbBefore - wbnb.balanceOf(address(this)), wbnbIn, "wbnb pulled");
//   //   assertEq(usdtBefore - usdt.balanceOf(address(this)), usdtIn, "usdt pulled");
//   //   assertApproxEqRel(vaultToken.balanceOf(address(this)), expectedEquity, 1e12, "shares received");

//   //   wbnbBefore = wbnb.balanceOf(address(this));
//   //   usdtBefore = usdt.balanceOf(address(this));

//   //   // Withdraw
//   //   vaultManager.withdraw(address(vaultToken), vaultToken.balanceOf(address(this)));

//   //   assertApproxEqRel(
//   //     wbnb.balanceOf(address(this)) - wbnbBefore, expectedAddLiquidityWBNB - wbnbIn, 1e12, "wbnb withdraw"
//   //   );
//   //   assertApproxEqRel(
//   //     usdt.balanceOf(address(this)) - usdtBefore, expectedAddLiquidityUSDT - usdtIn, 1e12, "usdt withdraw"
//   //   );
//   // }
// }

// // import "test/base/BaseForkTest.sol";

// // // contracts
// // import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
// // import { Bank } from "src/Bank.sol";
// // import { CommonV3LiquidityOracle } from "src/oracles/CommonV3LiquidityOracle.sol";
// // import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
// // import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
// // import { SimpleV3DepositExecutor } from "src/executors/SimpleV3DepositExecutor.sol";

// // // interfaces
// // import { IERC20 } from "src/interfaces/IERC20.sol";
// // import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

// // // mocks
// // import { MockMoneyMarket } from "test/mocks/MockMoneyMarket.sol";

// // contract AutomatedVaultIntegrationForkTest is BaseForkTest {
// //   int24 internal constant TICK_LOWER = -58000;
// //   int24 internal constant TICK_UPPER = -57750;
// //   uint16 internal constant PERFORMANCE_FEE_BPS = 1_000;

// //   MockMoneyMarket mockMoneyMarket;
// //   AutomatedVaultManager vaultManager;
// //   Bank bank;
// //   CommonV3LiquidityOracle pcsV3LiquidityOracle;
// //   PancakeV3Worker pcsV3Worker;
// //   PancakeV3VaultOracle pcsV3WorkerOracle;
// //   SimpleV3DepositExecutor depositExecutor;
// //   IERC20 vaultToken;

// //   function setUp() public override {
// //     super.setUp();

// //     vm.createSelectFork("bsc_mainnet", 27_515_914);
// //     deal(address(wbnb), ALICE, 100 ether);
// //     deal(address(usdt), ALICE, 100 ether);

// //     vm.startPrank(DEPLOYER);

// //     address[] memory tokensToSeed = new address[](2);
// //     tokensToSeed[0] = address(wbnb);
// //     tokensToSeed[1] = address(usdt);
// //     mockMoneyMarket = deployAndSeedMockMoneyMarket(tokensToSeed);

// //     pcsV3LiquidityOracle = deployLiquidityOracle(address(pancakeV3PositionManager), 6000, 10_500);
// //     pcsV3LiquidityOracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
// //     pcsV3LiquidityOracle.setPriceFeedOf(address(usdt), address(usdtFeed));

// //     vaultManager = deployAutomatedVaultManager();
// //     bank = deployBank(address(mockMoneyMarket), address(vaultManager));
// //     pcsV3Worker = deployPancakeV3Worker(
// //       PancakeV3Worker.ConstructorParams({
// //         vaultManager: vaultManager,
// //         positionManager: pancakeV3PositionManager,
// //         pool: pancakeV3USDTWBNBPool,
// //         router: pancakeV3Router,
// //         masterChef: pancakeV3MasterChef,
// //         zapV3: zapV3,
// //         performanceFeeBucket: PERFORMANCE_FEE_BUCKET,
// //         tickLower: TICK_LOWER,
// //         tickUpper: TICK_UPPER,
// //         performanceFeeBps: PERFORMANCE_FEE_BPS
// //       })
// //     );
// //     pcsV3WorkerOracle = new PancakeV3VaultOracle();

// //     depositExecutor = new SimpleV3DepositExecutor(address(bank));
// //     vaultToken = IERC20(
// //       vaultManager.openVault(
// //         "test vault",
// //         "TV",
// //         AutomatedVaultManager.VaultInfo({
// //           worker: address(pcsV3Worker),
// //           vaultOracle: address(pcsV3WorkerOracle),
// //           depositExecutor: address(depositExecutor)
// //         })
// //       )
// //     );

// //     vm.stopPrank();

// //     vm.startPrank(ALICE);
// //     wbnb.approve(address(vaultManager), 1 ether);
// //     usdt.approve(address(vaultManager), 2 ether);
// //     vm.stopPrank();
// //   }

// //   // TODO: revise this case after done with debt pricing
// //   // function testCorrectness_VaultManager_DepositToEmptyVault_ShouldGetSharesEqualToEquity() public {
// //   //   AutomatedVaultManager.TokenAmount[] memory deposits = new AutomatedVaultManager.TokenAmount[](2);
// //   //   deposits[0] = AutomatedVaultManager.TokenAmount({ token: address(wbnb), amount: 1 ether });
// //   //   deposits[1] = AutomatedVaultManager.TokenAmount({ token: address(usdt), amount: 2 ether });

// //   //   uint256 _balanceWBNBBefore = wbnb.balanceOf(ALICE);
// //   //   uint256 _balanceUSDTBefore = usdt.balanceOf(ALICE);

// //   //   vm.prank(ALICE);
// //   //   (, uint256 amount0, uint256 amount1) =
// //   //     abi.decode(vaultManager.deposit(address(vaultToken), deposits, abi.encode()), (uint128, uint256, uint256));

// //   //   (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
// //   //   uint256 usdtValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals());
// //   //   (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
// //   //   uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
// //   //   uint256 expectedPositionValueUSD = usdtValueUSD + wbnbValueUSD;

// //   //   // check deducted user's balance
// //   //   assertEq(_balanceWBNBBefore - 1 ether, wbnb.balanceOf(ALICE));
// //   //   assertEq(_balanceUSDTBefore - 2 ether, usdt.balanceOf(ALICE));
// //   //   // check equity
// //   //   assertApproxEqAbs(
// //   //     pcsV3LiquidityOracle.getPositionValueUSD(address(pcsV3Worker.pool()), pcsV3Worker.nftTokenId()),
// //   //     expectedPositionValueUSD,
// //   //     327
// //   //   );
// //   //   // check vault token minted to user
// //   //   assertApproxEqAbs(vaultToken.balanceOf(ALICE), expectedPositionValueUSD, 327);
// //   // }
// // }
