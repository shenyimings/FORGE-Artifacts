// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, LibPoolConfigV1, MockDonateVault, MockStrategy, console, GetterFacetInterface, LiquidityFacetInterface, stdError } from "./PoolDiamond_BaseTest.t.sol";
import { StrategyInterface } from "src/interfaces/StrategyInterface.sol";

contract PoolDiamond_Farm_IncreasePositionTest is PoolDiamond_BaseTest {
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

  function testCorrectness_WhenIncreasePosition_WhenLong_WhenStrategyProfit()
    external
  {
    wbtc.mint(ALICE, 1 * 10**8);

    // Set strategy target bps to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // ----- Start Alice session -----
    vm.startPrank(ALICE);

    // Alice add liquidity with 117499 satoshi
    wbtc.transfer(address(poolDiamond), 117499);
    poolLiquidityFacet.addLiquidity(ALICE, address(wbtc), ALICE);

    // After Alice added 117499 satoshi as a liquidity,
    // the following conditions should be met:
    // 1. Alice should get 46.8584 ALP
    // 2. Pool should make 353 sathoshi
    // 3. Pool's AUM by min price should be:
    // 0.00117499 * (1-0.003) * 40000 = 46.8584 USD
    // 4. Pool's AUM by max price should be:
    // 0.00117499 * (1-0.003) * 41000 = 48.02986 USD
    // 5. WBTC's USD debt should be 48.8584 USD
    // 6. WBTC's liquidity should be 117499 - 353 = 117146 satoshi
    // 7. Redeemable WBTC in USD should be 48.8584 USD
    assertEq(poolGetterFacet.alp().balanceOf(ALICE), 46.8584 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 353);
    assertEq(poolGetterFacet.getAumE18(false), 46.8584 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 48.02986 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 46.8584 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 117146);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      46.8584 * 10**30
    );
    vm.stopPrank();

    // Call farm to deploy funds 117146 * 50% = 58573 satoshi
    poolFarmFacet.farm(address(wbtc), true);

    vm.startPrank(ALICE);
    // Alice add liquidity again with 117499 satoshi
    wbtc.transfer(address(poolDiamond), 117499);
    poolLiquidityFacet.addLiquidity(ALICE, address(wbtc), ALICE);

    // After Alice added 117499 satoshi as a liquidity,
    // the following conditions should be met:
    // 1. Alice should get 46.8584 + (46.8584 * 46.8584 / 48.02986) = 92573912195121951219 ALP
    // 2. Pool should make 706 sathoshi
    // 3. Pool's AUM by min price should be:
    // 46.8584 + (0.00117499 * (1-0.003) * 40000) = 93.7168 USD
    // 4. Pool's AUM by max price should be:
    // 48.02986 + (0.00117499 * (1-0.003) * 41000) = 96.05972 USD
    // 5. WBTC's USD debt should be 93.7168 USD
    // 6. WBTC's liquidity should be 117146 + 117499 - 353 = 234292 satoshi
    // 7. Redeemable WBTC in USD should be 93.7168 USD
    // 8. Current WBTC in the pool contract is 234292 - 58573 = 175719 satoshi

    assertEq(
      poolGetterFacet.alp().balanceOf(ALICE),
      92.573912195121951219 ether
    );
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 706);
    assertEq(poolGetterFacet.getAumE18(false), 93.7168 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 96.05972 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234292);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      93.7168 * 10**30
    );
    assertEq(
      wbtc.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(wbtc)),
      175719
    );

    // Assuming vault profit 100000 satoshi
    wbtc.mint(address(mockWbtcVault), 100000);

    // The following conditions should be met:
    // 1. Wbtc's strategy delta should be: +100000 satoshi
    // 2. Wbtc's strategy should be profitable
    // 2. Pool's aum by min price should be:
    // = 93.7168 + (0.00100000 * 40000) [StrategyDelta]
    // = 133.7168e18 USD
    // 3. Pool's aum by max price should be:
    // = 96.05972 + (0.00100000 * 41000) [StrategyDelta]
    // = 137.05972e68 USD
    (bool isProfit, uint256 strategyDelta) = poolGetterFacet.getStrategyDeltaOf(
      address(wbtc)
    );
    assertEq(strategyDelta, 100000);
    assertTrue(isProfit);
    assertEq(poolGetterFacet.getAumE18(false), 133.7168 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 137.05972 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234292);

    // Increase long position with sub account id = 0
    wbtc.transfer(address(poolDiamond), 22500);
    poolPerpTradeFacet.increasePosition(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      49 * 10**30,
      true
    );

    // The following condition expected to be happened:
    // 1. Pool's WBTC liquidity should be:
    // = (234292 + 100001) + 22500 - (((49 * 0.001) + (49 * 0)) / 41000)
    // = 334293 + 22500 - (((49 * 0.001) + (49 * 0)) / 41000)
    // = 334293 + 22500 - 119 = 356674 sathoshi
    // 2. Pool's WBTC reserved should be:
    // = 49 / 40000 = 122500 sathoshi
    // 3. Pool's WBTC guarantee USD should be:
    // = 49 + 0.049 - ((22500 / 1e8) * 40000) = 40.049 USD
    // 4. Redeemable WBTC in USD should be:
    // = ((356674 + 97680 [from 40.049 converting to collateral token] - 122500) / 1e8) * 40000 = 132.7416 USD
    // 5. Pool's AUM by min price should be:
    // 40.049 + ((356673 - 122500) / 1e8) * 40000 = 133.7182 USD
    // 6. Pool's AUM by max price should be:
    // 40.049 + ((356673 - 122500) / 1e8) * 41000 = 136.05993 USD
    // 7. Pool should makes 706 + 119 = 825 sathoshi
    // 8. Pool's WBTC USD debt should still the same as before
    // 9. Pool's WBTC balance should be:
    // = 356674 + 825 (fee) - 58573 (which is in the farm strategy) = 298926 sathoshi
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 356674);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 122500);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 40.049 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      132.7416 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 133.7182 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 136.05993 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 825);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 298926);

    // Assert a postion
    // 1. Position's size should be 49 USD
    // 2. Position's collateral should be:
    // = ((22500 / 1e8) * 40000) - 0.049 = 8.951 USD
    // 3. Position's average price should be 41000 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 49 * 10**30);
    assertEq(position.collateral, 8.951 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 122500);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);

    vm.stopPrank();
  }

  function testCorrectness_WhenIncreasePosition_WhenLong_WhenStrategyLoss()
    external
  {
    wbtc.mint(ALICE, 1 * 10**8);

    // Set strategy target bps to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // ----- Start Alice session -----
    vm.startPrank(ALICE);

    // Alice add liquidity with 117499 satoshi
    wbtc.transfer(address(poolDiamond), 117499);
    poolLiquidityFacet.addLiquidity(ALICE, address(wbtc), ALICE);

    // After Alice added 117499 satoshi as a liquidity,
    // the following conditions should be met:
    // 1. Alice should get 46.8584 ALP
    // 2. Pool should make 353 sathoshi
    // 3. Pool's AUM by min price should be:
    // 0.00117499 * (1-0.003) * 40000 = 46.8584 USD
    // 4. Pool's AUM by max price should be:
    // 0.00117499 * (1-0.003) * 41000 = 48.02986 USD
    // 5. WBTC's USD debt should be 48.8584 USD
    // 6. WBTC's liquidity should be 117499 - 353 = 117146 satoshi
    // 7. Redeemable WBTC in USD should be 48.8584 USD
    assertEq(poolGetterFacet.alp().balanceOf(ALICE), 46.8584 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 353);
    assertEq(poolGetterFacet.getAumE18(false), 46.8584 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 48.02986 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 46.8584 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 117146);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      46.8584 * 10**30
    );
    vm.stopPrank();

    // Call farm to deploy funds 117146 * 50% = 58573 satoshi
    poolFarmFacet.farm(address(wbtc), true);

    vm.startPrank(ALICE);
    // Alice add liquidity again with 117499 satoshi
    wbtc.transfer(address(poolDiamond), 117499);
    poolLiquidityFacet.addLiquidity(ALICE, address(wbtc), ALICE);

    // After Alice added 117499 satoshi as a liquidity,
    // the following conditions should be met:
    // 1. Alice should get 46.8584 + (46.8584 * 46.8584 / 48.02986) = 92573912195121951219 ALP
    // 2. Pool should make 706 sathoshi
    // 3. Pool's AUM by min price should be:
    // 46.8584 + (0.00117499 * (1-0.003) * 40000) = 93.7168 USD
    // 4. Pool's AUM by max price should be:
    // 48.02986 + (0.00117499 * (1-0.003) * 41000) = 96.05972 USD
    // 5. WBTC's USD debt should be 93.7168 USD
    // 6. WBTC's liquidity should be 117146 + 117499 - 353 = 234292 satoshi
    // 7. Redeemable WBTC in USD should be 93.7168 USD
    // 8. Current WBTC in the pool contract is 234292 - 58573 = 175719 satoshi

    assertEq(
      poolGetterFacet.alp().balanceOf(ALICE),
      92.573912195121951219 ether
    );
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 706);
    assertEq(poolGetterFacet.getAumE18(false), 93.7168 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 96.05972 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234292);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      93.7168 * 10**30
    );
    assertEq(
      wbtc.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(wbtc)),
      175719
    );

    // Assuming vault lost 50000 satoshi
    wbtc.burn(address(mockWbtcVault), 50000);

    // The following conditions should be met:
    // 1. Wbtc's strategy delta should be: -50000 satoshi
    // 2. Wbtc's strategy should not be profitable
    // 2. Pool's aum by min price should be:
    // = 93.7168 - (0.00050000 * 40000) [StrategyDelta]
    // = 73.7168e18 USD
    // 3. Pool's aum by max price should be:
    // = 96.05972 - (0.00050000 * 41000) [StrategyDelta]
    // = 75.55972e68 USD
    (bool isProfit, uint256 strategyDelta) = poolGetterFacet.getStrategyDeltaOf(
      address(wbtc)
    );
    assertEq(strategyDelta, 50000);
    assertFalse(isProfit);
    assertEq(poolGetterFacet.getAumE18(false), 73.7168 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 75.55972 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234292);

    // Increase long position with sub account id = 0
    wbtc.transfer(address(poolDiamond), 22500);
    poolPerpTradeFacet.increasePosition(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      49 * 10**30,
      true
    );

    // The following condition expected to be happened:
    // 1. Pool's WBTC liquidity should be:
    // = (234292 - 50000) + 22500 - (((49 * 0.001) + (49 * 0)) / 41000)
    // = 184292 + 22500 - (((49 * 0.001) + (49 * 0)) / 41000)
    // = 184292 + 22500 - 119 = 206673 sathoshi
    // 2. Pool's WBTC reserved should be:
    // = 49 / 40000 = 122500 sathoshi
    // 3. Pool's WBTC guarantee USD should be:
    // = 49 + 0.049 - ((22500 / 1e8) * 40000) = 40.049 USD
    // 4. Redeemable WBTC in USD should be:
    // = ((206673 + 97680 [from 40.049 converting to collateral token] - 122500) / 1e8) * 40000
    // = ((206673 + 97680 - 122500) / 1e8) * 40000 = 72.7412 USD
    // 5. Pool's AUM by min price should be:
    // 40.049 + ((206673 - 122500) / 1e8) * 40000 = 73.7182 USD
    // 6. Pool's AUM by max price should be:
    // 40.049 + ((206673 - 122500) / 1e8) * 41000 = 74.55993 USD
    // 7. Pool should makes 706 + 119 = 825 sathoshi
    // 8. Pool's WBTC USD debt should still the same as before
    // 9. Pool's WBTC balance should be:
    // = 206673 + 825 (fee) - 8573 (which is in the farm strategy) = 198925 sathoshi
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 206673);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 122500);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 40.049 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      72.7412 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 73.7182 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 74.55993 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 825);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 198925);

    // Assert a postion
    // 1. Position's size should be 49 USD
    // 2. Position's collateral should be:
    // = ((22500 / 1e8) * 40000) - 0.049 = 8.951 USD
    // 3. Position's average price should be 41000 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 49 * 10**30);
    assertEq(position.collateral, 8.951 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 122500);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);

    vm.stopPrank();
  }

  function testCorrectness_WhenIncreasePosition_WhenShort_WhenStrategyProfit()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(1000 * 10**8);

    // Set mintBurnFeeBps to 4 BPS
    poolAdminFacet.setMintBurnFeeBps(4);

    // Feed WBTC price to be 40,000 USD
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Mint 1,000 DAI to Alice
    dai.mint(ALICE, 1000 * 10**18);

    // Mint 1 WBTC to this address
    wbtc.mint(address(this), 1 * 10**8);

    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);
    // Set strategy target bps for DAI to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);

    // Performs add liquidity with 117499 satoshi
    wbtc.transfer(address(poolDiamond), 117499);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // --- Start Alice session --- //
    vm.startPrank(ALICE);

    // Alice performs add liquidity by a 500 DAI
    dai.transfer(address(poolDiamond), 500 * 10**18);
    poolLiquidityFacet.addLiquidity(ALICE, address(dai), ALICE);

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 500 * (1-0.0004) = 499.8 DAI
    // 2. Pool should make 0.2 DAI in fee
    // 3. Pool's DAI usd debt should be 499.8 USD
    // 4. Redemptable DAI collateral should be 499.8 USD
    // 5. Pool's AUM by min price should be 499.8 + (0.00117499 * (1-0.0004) * 40000) = 546.7808 USD
    // 6. Pool's AUM by max price should be 499.8 + (0.00117499 * (1-0.0004) * 40000) = 546.7808 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.2 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      499.8 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 546.7808 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 546.7808 * 10**18);

    vm.stopPrank();
    // ---- Stop Alice session ---- //

    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Call farm to deploy funds 117499 - 47 [from 4 BPS fee] * 50% = 58726 satoshi
    poolFarmFacet.farm(address(wbtc), true);
    // Call farm to deploy funds 499.8 * 50% = 249.9 DAI
    poolFarmFacet.farm(address(dai), true);

    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 117452);
    assertEq(
      dai.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(dai)),
      249.9 ether
    );
    assertEq(
      wbtc.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(wbtc)),
      58726
    );

    // ---- Start Alice session ---- //
    vm.startPrank(ALICE);

    // Assuming WBTC vault profits 100000 satoshi
    wbtc.mint(address(mockWbtcVault), 100000);
    // Assuming DAI vault profits 20 DAI
    dai.mint(address(mockDaiVault), 20 * 10**18);

    // Alice opens a 90 USD WBTC short position with 20 DAI as a collateral
    dai.transfer(address(poolDiamond), 20 * 10**18);
    poolPerpTradeFacet.increasePosition(
      ALICE,
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be the same.
    // 2. Pool's DAI USD debt should be the same.
    // 2. Pool's DAI reserved should be 90 DAI
    // 3. Pool's guaranteed USD should be 0
    // 4. Redemptable DAI collateral should be 499.8 USD + 20 USD [from strategy profit] = 519.8 USD
    // 5. Pool should makes 0.2 + ((90 * 0.001)) = 0.29 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 519.8 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      519.8 * 10**30
    );
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.29 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );

    // Assert a position:
    // 1. Position's size should be 90
    // 2. Position's collateral should be 20 - (90 * 0.001) = 19.91 DAI
    // 3. Position's averagePrice should be 40,000 USD
    // 4. Position's entry funding rate should be 0
    // 5. Position's reserve amount should be 90 DAI
    // 6. Position should be in profit
    // 7. Position's lastIncreasedTime should be block.timestamp
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 19.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertTrue(position.hasProfit);
    assertEq(position.lastIncreasedTime, block.timestamp);

    // Assert pool's short delta
    // 1. Pool's delta should be (90 * (40000 - 41000)) / 40000 = -2.25 USD
    // 2. Pool's short should be not profitable
    (bool isProfit, uint256 delta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertFalse(isProfit);
    assertEq(delta, 2.25 * 10**30);

    // Assert position's delta
    // 1. Position's delta should be (90 * (40000 - 41000)) / 40000 = -2.25 USD
    // 2. Position's short should be not profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertFalse(isProfit);
    assertEq(delta, 2.25 * 10**30);

    vm.stopPrank();

    // Make WBTC price pump to 42,000 USD
    wbtcPriceFeed.setLatestAnswer(42_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(42_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(42_000 * 10**8);

    vm.startPrank(ALICE);

    // Assert pool's short delta
    // 1. Pool's delta should be (90 * (40000 - 42000)) / 40000 = -4.5 USD
    // 2. Pool's short should be not profitable
    (isProfit, delta) = poolGetterFacet.getPoolShortDelta(address(wbtc));
    assertFalse(isProfit);
    assertEq(delta, 4.5 * 10**30);

    // Assert position's delta
    // 1. Position's delta should be (90 * (40000 - 42000)) / 40000 = -4.5 USD
    // 2. Position's short should be not profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertFalse(isProfit);
    assertEq(delta, 4.5 * 10**30);
  }

  function testCorrectness_WhenIncreasePosition_WhenShort_WhenStrategyLoss()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(1000 * 10**8);

    // Set mintBurnFeeBps to 4 BPS
    poolAdminFacet.setMintBurnFeeBps(4);

    // Feed WBTC price to be 40,000 USD
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Mint 1,000 DAI to Alice
    dai.mint(ALICE, 1000 * 10**18);

    // Mint 1 WBTC to this address
    wbtc.mint(address(this), 1 * 10**8);

    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);
    // Set strategy target bps for DAI to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);

    // Performs add liquidity with 117499 satoshi
    wbtc.transfer(address(poolDiamond), 117499);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // --- Start Alice session --- //
    vm.startPrank(ALICE);

    // Alice performs add liquidity by a 500 DAI
    dai.transfer(address(poolDiamond), 500 * 10**18);
    poolLiquidityFacet.addLiquidity(ALICE, address(dai), ALICE);

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 500 * (1-0.0004) = 499.8 DAI
    // 2. Pool should make 0.2 DAI in fee
    // 3. Pool's DAI usd debt should be 499.8 USD
    // 4. Redemptable DAI collateral should be 499.8 USD
    // 5. Pool's AUM by min price should be 499.8 + (0.00117499 * (1-0.0004) * 40000) = 546.7808 USD
    // 6. Pool's AUM by max price should be 499.8 + (0.00117499 * (1-0.0004) * 40000) = 546.7808 USD (based on the test case, min price currently equals to max price)
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.2 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      499.8 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 546.7808 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 546.7808 * 10**18);

    vm.stopPrank();
    // ---- Stop Alice session ---- //

    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Call farm to deploy funds 117499 - 47 [from 4 BPS fee] * 50% = 58726 satoshi
    poolFarmFacet.farm(address(wbtc), true);
    // Call farm to deploy funds 499.8 * 50% = 249.9 DAI
    poolFarmFacet.farm(address(dai), true);

    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 117452);
    assertEq(
      dai.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(dai)),
      249.9 ether
    );
    assertEq(
      wbtc.balanceOf(address(poolDiamond)) -
        poolGetterFacet.feeReserveOf(address(wbtc)),
      58726
    );

    // ---- Start Alice session ---- //
    vm.startPrank(ALICE);

    // Assuming WBTC vault profits 50000 satoshi
    wbtc.burn(address(mockWbtcVault), 50000);
    // Assuming DAI vault profits 20 DAI
    dai.burn(address(mockDaiVault), 20 * 10**18);

    // Alice opens a 90 USD WBTC short position with 20 DAI as a collateral
    dai.transfer(address(poolDiamond), 20 * 10**18);
    poolPerpTradeFacet.increasePosition(
      ALICE,
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be the same.
    // 2. Pool's DAI USD debt should be the same.
    // 2. Pool's DAI reserved should be 90 DAI
    // 3. Pool's guaranteed USD should be 0
    // 4. Redemptable DAI collateral should be 499.8 USD - 20 USD [from strategy profit] = 479.8 USD
    // 5. Pool should makes 0.2 + ((90 * 0.001)) = 0.29 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 479.8 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      479.8 * 10**30
    );
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.29 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );

    // Assert a position:
    // 1. Position's size should be 90
    // 2. Position's collateral should be 20 - (90 * 0.001) = 19.91 DAI
    // 3. Position's averagePrice should be 40,000 USD
    // 4. Position's entry funding rate should be 0
    // 5. Position's reserve amount should be 90 DAI
    // 6. Position should be in profit
    // 7. Position's lastIncreasedTime should be block.timestamp
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 19.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertTrue(position.hasProfit);
    assertEq(position.lastIncreasedTime, block.timestamp);

    // Assert pool's short delta
    // 1. Pool's delta should be (90 * (40000 - 41000)) / 40000 = -2.25 USD
    // 2. Pool's short should be not profitable
    (bool isProfit, uint256 delta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertFalse(isProfit);
    assertEq(delta, 2.25 * 10**30);

    // Assert position's delta
    // 1. Position's delta should be (90 * (40000 - 41000)) / 40000 = -2.25 USD
    // 2. Position's short should be not profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertFalse(isProfit);
    assertEq(delta, 2.25 * 10**30);

    vm.stopPrank();

    // Make WBTC price pump to 42,000 USD
    wbtcPriceFeed.setLatestAnswer(42_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(42_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(42_000 * 10**8);

    vm.startPrank(ALICE);

    // Assert pool's short delta
    // 1. Pool's delta should be (90 * (40000 - 42000)) / 40000 = -4.5 USD
    // 2. Pool's short should be not profitable
    (isProfit, delta) = poolGetterFacet.getPoolShortDelta(address(wbtc));
    assertFalse(isProfit);
    assertEq(delta, 4.5 * 10**30);

    // Assert position's delta
    // 1. Position's delta should be (90 * (40000 - 42000)) / 40000 = -4.5 USD
    // 2. Position's short should be not profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertFalse(isProfit);
    assertEq(delta, 4.5 * 10**30);
  }
}
