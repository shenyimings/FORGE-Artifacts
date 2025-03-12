// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, LibPoolConfigV1, MockDonateVault, MockStrategy, console, GetterFacetInterface, LiquidityFacetInterface, stdError } from "./PoolDiamond_BaseTest.t.sol";
import { StrategyInterface } from "src/interfaces/StrategyInterface.sol";

contract PoolDiamond_Farm_SwapTest is PoolDiamond_BaseTest {
  MockDonateVault internal mockDaiVault;
  MockStrategy internal mockDaiVaultStrategy;

  MockDonateVault internal mockWbtcVault;
  MockStrategy internal mockWbtcVaultStrategy;

  MockDonateVault internal mockBnbVault;
  MockStrategy internal mockBnbVaultStrategy;

  function setUp() public override {
    super.setUp();

    (
      address[] memory tokens2,
      LibPoolConfigV1.TokenConfig[] memory tokenConfigs2
    ) = buildDefaultSetTokenConfigInput2();

    poolAdminFacet.setTokenConfigs(tokens2, tokenConfigs2);

    // Feed prices
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);

    // Deploy strategy related-instances

    // DaiVault
    mockDaiVault = new MockDonateVault(address(dai));
    mockDaiVaultStrategy = new MockStrategy(
      address(dai),
      mockDaiVault,
      address(poolDiamond)
    );

    // WbtcVault
    mockWbtcVault = new MockDonateVault(address(wbtc));
    mockWbtcVaultStrategy = new MockStrategy(
      address(wbtc),
      mockWbtcVault,
      address(poolDiamond)
    );

    // BnbVault
    mockBnbVault = new MockDonateVault(address(bnb));
    mockBnbVaultStrategy = new MockStrategy(
      address(bnb),
      mockBnbVault,
      address(poolDiamond)
    );

    // Set and commit DAI strategy
    poolFarmFacet.setStrategyOf(address(dai), mockDaiVaultStrategy);
    vm.warp(block.timestamp + 1 weeks + 1);
    poolFarmFacet.setStrategyOf(address(dai), mockDaiVaultStrategy);

    // Set and commit WBTC strategy
    poolFarmFacet.setStrategyOf(address(wbtc), mockWbtcVaultStrategy);
    vm.warp(block.timestamp + 1 weeks + 1);
    poolFarmFacet.setStrategyOf(address(wbtc), mockWbtcVaultStrategy);

    // Set and commit BNB strategy
    poolFarmFacet.setStrategyOf(address(bnb), mockBnbVaultStrategy);
    vm.warp(block.timestamp + 1 weeks + 1);
    poolFarmFacet.setStrategyOf(address(bnb), mockBnbVaultStrategy);
  }

  function testCorrectness_WhenSwap_WhenStrategyProfit() external {
    // Reset latest 3
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);

    bnb.mint(ALICE, 200 ether);
    wbtc.mint(ALICE, 1 * 10**8);

    // Set strategy target bps for WBTC to be 95%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 9500);
    // Set strategy target bps for BNB to be 95%
    poolFarmFacet.setStrategyTargetBps(address(bnb), 9500);

    // ------- Alice session START -------
    vm.startPrank(ALICE);

    // Alice add liquidity 200 BNB (~$60,000)
    bnb.transfer(address(poolDiamond), 200 ether);
    poolLiquidityFacet.addLiquidity(ALICE, address(bnb), ALICE);

    // Alice add 200 BNB as liquidity to the pool, the following condition is expected:
    // 1. Pool should have 200 * (1-0.003) * 300 = 59820 USD in AUM
    assertEq(poolGetterFacet.getAumE18(false), 59820 ether);

    // Alice add liquidity 1 WBTC (~$60,000)
    wbtc.transfer(address(poolDiamond), 1 * 10**8);
    poolLiquidityFacet.addLiquidity(ALICE, address(wbtc), ALICE);

    // Alice add another 1 WBTC as liquidity to the pool, the following condition is expected:
    // 1. Pool should have 59,820 + (1 * (1-0.003) * 60000) = 119,640 USD in AUM
    // 2. Alice should have 119,640 ALP
    // 3. Pool should make 200 * 0.003 = 0.6 BNB in fee
    // 4. Pool should make 1 * 0.003 = 0.003 WBTC in fee
    // 5. USD debt for BNB should be 59,820 USD
    // 6. USD debt for WBTC should be 59,820 USD
    // 7. Pool's BNB liquidity should be 200 * (1-0.003) = 199.4 BNB
    // 8. Pool's WBTC liquidity should be 1 * (1-0.003) = 0.997 WBTC
    assertEq(poolGetterFacet.getAumE18(false), 119640 ether);
    assertEq(poolGetterFacet.alp().balanceOf(ALICE), 119640 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(bnb)), 0.6 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 300000);
    assertEq(poolGetterFacet.usdDebtOf(address(bnb)), 59820 ether);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 59820 ether);
    assertEq(poolGetterFacet.liquidityOf(address(bnb)), 199.4 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.997 * 10**8);

    vm.stopPrank();
    // ------- Alice session END -------

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(600 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);

    // Oracle price updates, the following condition is expected:
    // 1. Pool should have (199.4 * 400) + (0.997 * 60000) = 139,580 USD
    assertEq(poolGetterFacet.getAumE18(false), 139580 ether);

    wbtcPriceFeed.setLatestAnswer(90000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(100000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(80000 * 10**8);

    // Oracle price updates, the following condition is expected:
    // 1. Pool should have (199.4 * 400) + (0.997 * 80000) = 159,520 USD
    assertEq(poolGetterFacet.getAumE18(false), 159520 ether);

    bnb.mint(BOB, 100 ether);

    // Call farm to deploy funds 0.997 * 95% = 0.94715, hence balance of pool (excluded fee) will be 0.997 - 0.94715 = 0.04985
    poolFarmFacet.farm(address(wbtc), true);
    // Call farm to deploy funds 199.4 * 95% = 189.43, hence balance of pool (excluded fee) will be 199.4 - 189.43 = 9.97
    poolFarmFacet.farm(address(bnb), true);

    assertEq(poolGetterFacet.liquidityOf(address(bnb)), 199.4 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.997 * 10**8);
    assertEq(
      bnb.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(bnb)),
      9.97 ether
    );
    assertEq(
      wbtc.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(wbtc)),
      0.04985 * 10**8
    );

    // Assuming WBTC vault profits 100000 satoshi
    wbtc.mint(address(mockWbtcVault), 100000);
    // Assuming BNB vault profits 20 BNB
    bnb.mint(address(mockBnbVault), 20 ether);

    // ------- Bob session START -------
    vm.startPrank(BOB);

    // Bob swap 100 BNB for WBTC
    bnb.transfer(address(poolDiamond), 100 ether);
    poolLiquidityFacet.swap(BOB, address(bnb), address(wbtc), 0, BOB);

    // After Bob swap, the following condition is expected:
    // 1. Pool should have ((199.4 + 20) * 400) + ((0.997 + 0.001)  * 80000) + (100 * 400) - ((100 * 400 / 100000) * 80000) = 175600 USD in AUM
    // 2. Bob should get (100 * 400 / 100000) * (1 - 0.003) = 0.3988 WBTC
    // 3. Pool should make 200 * 0.003 = 0.6 BNB in fee
    // 4. Pool should make (1 * 0.003) + ((100 * 400 / 100000) * 0.003) = 0.0042 WBTC in fee
    // 5. USD debt for BNB should be 59820 + (100 * 400) = 99820 USD
    // 6. USD debt for WBTC should be 59820 - (100 * 400) = 19820 USD
    // 7. Pool's BNB liquidity should be 199.4 + 100 + 20 [from strategy profit] = 319.4 BNB
    // 8. Pool's WBTC liquidity should be 0.997 - ((100 * 400 / 100000)) + 0.001 [from strategy profit] = 0.598 WBTC
    assertEq(poolGetterFacet.getAumE18(false), 175600 ether);
    assertEq(wbtc.balanceOf(BOB), 0.3988 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(bnb)), 0.6 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 0.0042 * 10**8);
    assertEq(poolGetterFacet.usdDebtOf(address(bnb)), 99820 ether);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 19820 ether);
    assertEq(poolGetterFacet.liquidityOf(address(bnb)), 319.4 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.598 * 10**8);

    vm.stopPrank();
    // ------- Bob session END -------

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);
    bnbPriceFeed.setLatestAnswer(450 * 10**8);

    // ------- Alice session START -------
    vm.startPrank(ALICE);

    // Warp so that Alice can withdraw her ALP
    vm.warp(block.timestamp + 1 days + 1);

    // Alice remove 50000 USD worth of ALP from the pool with BNB as tokenOut
    poolGetterFacet.alp().transfer(
      address(poolDiamond),
      (50_000 ether * poolGetterFacet.alp().totalSupply()) /
        poolGetterFacet.getAumE18(false)
    );
    poolLiquidityFacet.removeLiquidity(ALICE, address(bnb), ALICE);

    assertEq(poolGetterFacet.alp().balanceOf(address(poolDiamond)), 0);

    // Alice expected to get 50000 / 500 * (1-0.003) = 99.7 BNB
    assertEq(bnb.balanceOf(ALICE), 99699999999999999999);

    // Alice remove 50000 USD worth of ALP from the pool with WBTC as tokenOut
    poolGetterFacet.alp().transfer(
      address(poolDiamond),
      (50_000 ether * poolGetterFacet.alp().totalSupply()) /
        poolGetterFacet.getAumE18(false)
    );
    poolLiquidityFacet.removeLiquidity(ALICE, address(wbtc), ALICE);

    // Alice expected to get 50000 / 100000 * (1-0.003) = 0.4985 WBTC
    assertEq(wbtc.balanceOf(ALICE), 49849999);

    // Alice try remove 10000 USD worth of ALP from the pool with WBTC as tokenOut
    // Pool doesn't has any liquidity left, so this should revert
    uint256 alpNeeded = (10_000 ether * poolGetterFacet.alp().totalSupply()) /
      poolGetterFacet.getAumE18(false);
    poolGetterFacet.alp().transfer(address(poolDiamond), alpNeeded);
    vm.expectRevert(stdError.arithmeticError);
    poolLiquidityFacet.removeLiquidity(ALICE, address(wbtc), ALICE);
  }

  function testCorrectness_WhenSwap_WhenStrategyLoss() external {
    // Reset latest 3
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);

    bnb.mint(ALICE, 200 ether);
    wbtc.mint(ALICE, 1 * 10**8);

    // Set strategy target bps for WBTC to be 95%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 9500);
    // Set strategy target bps for BNB to be 95%
    poolFarmFacet.setStrategyTargetBps(address(bnb), 9500);

    // ------- Alice session START -------
    vm.startPrank(ALICE);

    // Alice add liquidity 200 BNB (~$60,000)
    bnb.transfer(address(poolDiamond), 200 ether);
    poolLiquidityFacet.addLiquidity(ALICE, address(bnb), ALICE);

    // Alice add 200 BNB as liquidity to the pool, the following condition is expected:
    // 1. Pool should have 200 * (1-0.003) * 300 = 59820 USD in AUM
    assertEq(poolGetterFacet.getAumE18(false), 59820 ether);

    // Alice add liquidity 1 WBTC (~$60,000)
    wbtc.transfer(address(poolDiamond), 1 * 10**8);
    poolLiquidityFacet.addLiquidity(ALICE, address(wbtc), ALICE);

    // Alice add another 1 WBTC as liquidity to the pool, the following condition is expected:
    // 1. Pool should have 59,820 + (1 * (1-0.003) * 60000) = 119,640 USD in AUM
    // 2. Alice should have 119,640 ALP
    // 3. Pool should make 200 * 0.003 = 0.6 BNB in fee
    // 4. Pool should make 1 * 0.003 = 0.003 WBTC in fee
    // 5. USD debt for BNB should be 59,820 USD
    // 6. USD debt for WBTC should be 59,820 USD
    // 7. Pool's BNB liquidity should be 200 * (1-0.003) = 199.4 BNB
    // 8. Pool's WBTC liquidity should be 1 * (1-0.003) = 0.997 WBTC
    assertEq(poolGetterFacet.getAumE18(false), 119640 ether);
    assertEq(poolGetterFacet.alp().balanceOf(ALICE), 119640 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(bnb)), 0.6 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 300000);
    assertEq(poolGetterFacet.usdDebtOf(address(bnb)), 59820 ether);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 59820 ether);
    assertEq(poolGetterFacet.liquidityOf(address(bnb)), 199.4 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.997 * 10**8);

    vm.stopPrank();
    // ------- Alice session END -------

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(600 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);

    // Oracle price updates, the following condition is expected:
    // 1. Pool should have (199.4 * 400) + (0.997 * 60000) = 139,580 USD
    assertEq(poolGetterFacet.getAumE18(false), 139580 ether);

    wbtcPriceFeed.setLatestAnswer(90000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(100000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(80000 * 10**8);

    // Oracle price updates, the following condition is expected:
    // 1. Pool should have (199.4 * 400) + (0.997 * 80000) = 159,520 USD
    assertEq(poolGetterFacet.getAumE18(false), 159520 ether);

    bnb.mint(BOB, 100 ether);

    // Call farm to deploy funds 0.997 * 95% = 0.94715, hence balance of pool (excluded fee) will be 0.997 - 0.94715 = 0.04985
    poolFarmFacet.farm(address(wbtc), true);
    // Call farm to deploy funds 199.4 * 95% = 189.43, hence balance of pool (excluded fee) will be 199.4 - 189.43 = 9.97
    poolFarmFacet.farm(address(bnb), true);

    assertEq(poolGetterFacet.liquidityOf(address(bnb)), 199.4 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.997 * 10**8);
    assertEq(
      bnb.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(bnb)),
      9.97 ether
    );
    assertEq(
      wbtc.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(wbtc)),
      0.04985 * 10**8
    );

    // Assuming WBTC vault loss 50000 satoshi
    wbtc.burn(address(mockWbtcVault), 50000);
    // Assuming BNB vault loss 20 BNB
    // NOTE: Since bnb is a Wnative token, hence needs to do this workaround to do something similar to burn mechanism
    vm.prank(address(mockBnbVault), address(mockBnbVault));
    bnb.transfer(address(0), 20 ether);

    // ------- Bob session START -------
    vm.startPrank(BOB);

    // Bob swap 100 BNB for WBTC
    bnb.transfer(address(poolDiamond), 100 ether);
    poolLiquidityFacet.swap(BOB, address(bnb), address(wbtc), 0, BOB);

    // After Bob swap, the following condition is expected:
    // 1. Pool should have ((199.4 - 20) * 400) + ((0.997 - 0.0005)  * 80000) + (100 * 400) - ((100 * 400 / 100000) * 80000) = 159480 USD in AUM
    // 2. Bob should get (100 * 400 / 100000) * (1 - 0.003) = 0.3988 WBTC
    // 3. Pool should make 200 * 0.003 = 0.6 BNB in fee
    // 4. Pool should make (1 * 0.003) + ((100 * 400 / 100000) * 0.003) = 0.0042 WBTC in fee
    // 5. USD debt for BNB should be 59820 + (100 * 400) = 99820 USD
    // 6. USD debt for WBTC should be 59820 - (100 * 400) = 19820 USD
    // 7. Pool's BNB liquidity should be 199.4 + 100 - 20 [from strategy profit] = 279.4 BNB
    // 8. Pool's WBTC liquidity should be 0.997 - ((100 * 400 / 100000)) - 0.0005 [from strategy profit] = 0.5965 WBTC
    assertEq(poolGetterFacet.getAumE18(false), 159480 ether);
    assertEq(wbtc.balanceOf(BOB), 0.3988 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(bnb)), 0.6 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 0.0042 * 10**8);
    assertEq(poolGetterFacet.usdDebtOf(address(bnb)), 99820 ether);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 19820 ether);
    assertEq(poolGetterFacet.liquidityOf(address(bnb)), 279.4 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.5965 * 10**8);

    vm.stopPrank();
    // ------- Bob session END -------

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);
    bnbPriceFeed.setLatestAnswer(450 * 10**8);

    // ------- Alice session START -------
    vm.startPrank(ALICE);

    // Warp so that Alice can withdraw her ALP
    vm.warp(block.timestamp + 1 days + 1);

    // Alice remove 50000 USD worth of ALP from the pool with BNB as tokenOut
    poolGetterFacet.alp().transfer(
      address(poolDiamond),
      (50_000 ether * poolGetterFacet.alp().totalSupply()) /
        poolGetterFacet.getAumE18(false)
    );
    poolLiquidityFacet.removeLiquidity(ALICE, address(bnb), ALICE);

    assertEq(poolGetterFacet.alp().balanceOf(address(poolDiamond)), 0);

    // Alice expected to get 50000 / 500 * (1-0.003) = 99.7 BNB
    assertEq(bnb.balanceOf(ALICE), 99699999999999999999);

    // Alice remove 50000 USD worth of ALP from the pool with WBTC as tokenOut
    poolGetterFacet.alp().transfer(
      address(poolDiamond),
      (50_000 ether * poolGetterFacet.alp().totalSupply()) /
        poolGetterFacet.getAumE18(false)
    );
    poolLiquidityFacet.removeLiquidity(ALICE, address(wbtc), ALICE);

    // Alice expected to get 50000 / 100000 * (1-0.003) = 0.4985 WBTC
    assertEq(wbtc.balanceOf(ALICE), 49849999);

    // Alice try remove 10000 USD worth of ALP from the pool with WBTC as tokenOut
    // Pool doesn't has any liquidity left, so this should revert
    uint256 alpNeeded = (10_000 ether * poolGetterFacet.alp().totalSupply()) /
      poolGetterFacet.getAumE18(false);
    poolGetterFacet.alp().transfer(address(poolDiamond), alpNeeded);
    vm.expectRevert(stdError.arithmeticError);
    poolLiquidityFacet.removeLiquidity(ALICE, address(wbtc), ALICE);
  }
}
