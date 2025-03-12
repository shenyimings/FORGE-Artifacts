// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, LibPoolConfigV1, MockDonateVault, MockStrategy, console, GetterFacetInterface, LiquidityFacetInterface, stdError } from "./PoolDiamond_BaseTest.t.sol";
import { StrategyInterface } from "src/interfaces/StrategyInterface.sol";

contract PoolDiamond_Farm_DecreasePositionTest is PoolDiamond_BaseTest {
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

  function testCorrectness_WhenLong_WhenProfitable_WhenClosePosition_WhenStrategyProfit()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000 - 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Call farm to deploy funds 0.0024925 * 50% = 0.00124625 satoshi
    poolFarmFacet.farm(address(wbtc), true);

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 41000 = 102.1925 USD
    // 3. WBTC left in the pool will be 0.0025 - 0.00124625 = 0.00125375
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.1925 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(wbtc)), 0.00125375 * 10**8);

    // Assuming WBTC vault profits 100000 satoshi
    wbtc.mint(address(mockWbtcVault), 100000);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 41000)
    // = 0.0024925 + 0.00025 - (219 / 1e8)
    // = 0.00274031 + 0.00100001 WBTC [1 satoshi from round-up strategy] [getAum will rebalance the remaining to 0.00100000]
    // = 0.00374032 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.0025 WBTC
    // 4. Pool should make:
    // = 750 + 219
    // = 969 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00374031 - 0.00225) * 40000)
    // = 139.7024 USD
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00374031 - 0.00225) * 41000)
    // = 141.19271 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00374032 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 969);
    assertEq(poolGetterFacet.getAumE18(false), 139.7024 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 141.19271 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 41000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryFundingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Assuming WBTC price increase
    wbtcPriceFeed.setLatestAnswer(45_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(46_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((45100 - 41000) / 41000)
    // = 9 USD
    // 2. Position should be profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Close position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      90 * 10**30,
      true,
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 274031 + 100000  - ((90 * 0.001) / 47100 * 1e8) - (((9.91 + 9) / 47100 * 1e8) - ((90 * 0.001) / 47100 * 1e8))
    // = 274031 + 100000 - (40148 - 191) - 191
    // = 333883 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 9.91 - 90
    // = 0 USD
    // 3. Pool's WBTC reserved should be: 0 WBTC
    // 4. Pool should make:
    // = 969 + 191
    // = 1160 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 333883 * 45100 / 1e8
    // = 150.581233 USD
    // 6. Pool's AUM by max price should be:
    // = 333883 * 47100 / 1e8
    // = 157.258893 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 333883);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1160);
    assertEq(poolGetterFacet.getAumE18(false), 150.581233 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 157.258893 * 10**18);

    // Assert position. Everything should be zero.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.primaryAccount, address(0));

    // Assert position's owner WBTC balance
    // It should be:
    // = (((9.91 + 9) / 47100 * 1e8) - ((90 * 0.001) / 47100 * 1e8))
    // = 39957 sats
    assertEq(wbtc.balanceOf(address(this)), 39957);
  }

  function testCorrectness_WhenLong_WhenProfitable_WhenClosePosition_WhenStrategyLoss()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000 - 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Call farm to deploy funds 0.0024925 * 50% = 0.00124625 satoshi
    poolFarmFacet.farm(address(wbtc), true);

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 41000 = 102.1925 USD
    // 3. WBTC left in the pool will be 0.0025 - 0.00124625 = 0.00125375
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.1925 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(wbtc)), 0.00125375 * 10**8);

    // Assuming WBTC vault lost 5000 satoshi
    wbtc.burn(address(mockWbtcVault), 5000);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 41000)
    // = 0.0024925 + 0.00025 - (219 / 1e8)
    // = 0.00274031 - 0.00005000 WBTC
    // = 0.00269031 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.0025 WBTC
    // 4. Pool should make:
    // = 750 + 219
    // = 969 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00269031 - 0.00225) * 40000)
    // = 97.7024 USD
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00269031 - 0.00225) * 41000)
    // = 98.14271 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00269031 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 969);
    assertEq(poolGetterFacet.getAumE18(false), 97.7024 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 98.14271 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 41000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryFundingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Assuming WBTC price increase
    wbtcPriceFeed.setLatestAnswer(45_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(46_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((45100 - 41000) / 41000)
    // = 9 USD
    // 2. Position should be profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Close position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      90 * 10**30,
      true,
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 274031 - 5000 - ((90 * 0.001) / 47100 * 1e8) - (((9.91 + 9) / 47100 * 1e8) - ((90 * 0.001) / 47100 * 1e8))
    // = 274031 - 5000 - (40148 - 191) - 191
    // = 228883 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 9.91 - 90
    // = 0 USD
    // 3. Pool's WBTC reserved should be: 0 WBTC
    // 4. Pool should make:
    // = 969 + 191
    // = 1160 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 228883 * 45100 / 1e8
    // = 103.226233 USD
    // 6. Pool's AUM by max price should be:
    // = 228883 * 47100 / 1e8
    // = 107.803893 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 228883);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1160);
    assertEq(poolGetterFacet.getAumE18(false), 103.226233 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 107.803893 * 10**18);

    // Assert position. Everything should be zero.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.primaryAccount, address(0));

    // Assert position's owner WBTC balance
    // It should be:
    // = (((9.91 + 9) / 47100 * 1e8) - ((90 * 0.001) / 47100 * 1e8))
    // = 39957 sats
    assertEq(wbtc.balanceOf(address(this)), 39957);
  }

  function testCorrectness_WhenLong_WhenLoss_WhenClosePosition_WhenStrategyProfit()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000 - 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Call farm to deploy funds 0.0024925 * 50% = 0.00124625 satoshi
    poolFarmFacet.farm(address(wbtc), true);

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 41000 = 102.1925 USD
    // 3. WBTC left in the pool will be 0.0025 - 0.00124625 = 0.00125375
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.1925 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(wbtc)), 0.00125375 * 10**8);

    // Assuming WBTC vault profits 100000 satoshi
    wbtc.mint(address(mockWbtcVault), 100000);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 41000)
    // = 0.00274031 + 0.00100001 WBTC (1 satoshi from round-up strategy) (getAum will rebalance the remaining to 0.00100000)
    // = 0.00374032 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.0025 WBTC
    // 4. Pool should make:
    // = 750 + 219
    // = 969 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 40000)
    // = 139.7024 USD
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 41000)
    // = 141.19271 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00374032 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 969);
    assertEq(poolGetterFacet.getAumE18(false), 139.7024 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 141.19271 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 41000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryFundingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Assuming WBTC price decrease
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);

    // Assert position's delta.
    // 1. Position's delta should be:
    // = 90 * ((39000 - 41000) / 41000)
    // = -4.390243902439025 USD
    // 2. Position should be loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 4390243902439024390243902439024);
    assertFalse(isProfit);

    // Close position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      90 * 10**30,
      true,
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 274031 + 100000 - ((90 * 0.001) / 39000 * 1e8) - (((9.91 - 4.390243902439024390243902439024) / 39000 * 1e8) - ((90 * 0.001) / 39000 * 1e8))
    // = 274031 + 100000 - 230 - (14153 - 230)
    // = 359878 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 9.91 - 90
    // = 0 USD
    // 3. Pool's WBTC reserved should be: 0 WBTC
    // 4. Pool should make:
    // = 969 + 230
    // = 1199 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 359878 * 39000 / 1e8
    // = 140.35242 USD
    // 6. Pool's AUM by max price should be:
    // = 359878 * 39000 / 1e8
    // = 140.35242 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 359878);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1199);
    assertEq(poolGetterFacet.getAumE18(false), 140.35242 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 140.35242 * 10**18);

    // Assert position. Everything should be zero.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.primaryAccount, address(0));

    // Assert position's owner WBTC balance
    // It should be:
    // = (((9.91 - 4.390243902439024390243902439024) / 39000 * 1e8) - ((90 * 0.001) / 39000 * 1e8))
    // = 13922 sats
    assertEq(wbtc.balanceOf(address(this)), 13922);
  }

  function testCorrectness_WhenLong_WhenLoss_WhenClosePosition_WhenStrategyLoss()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000 - 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Call farm to deploy funds 0.0024925 * 50% = 0.00124625 satoshi
    poolFarmFacet.farm(address(wbtc), true);

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 41000 = 102.1925 USD
    // 3. WBTC left in the pool will be 0.0025 - 0.00124625 = 0.00125375
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.1925 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(wbtc)), 0.00125375 * 10**8);

    // Assuming WBTC vault lost 5000 satoshi
    wbtc.burn(address(mockWbtcVault), 5000);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 41000)
    // = 0.00274031 - 0.00005000 WBTC
    // = 0.00269031 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.0025 WBTC
    // 4. Pool should make:
    // = 750 + 219
    // = 969 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00269031 - 0.00225) * 40000)
    // = 97.7024 USD
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00269031 - 0.00225) * 41000)
    // = 98.14271 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00269031 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 969);
    assertEq(poolGetterFacet.getAumE18(false), 97.7024 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 98.14271 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 41000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryFundingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Assuming WBTC price decrease
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);

    // Assert position's delta.
    // 1. Position's delta should be:
    // = 90 * ((39000 - 41000) / 41000)
    // = -4.390243902439025 USD
    // 2. Position should be loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 4390243902439024390243902439024);
    assertFalse(isProfit);

    // Close position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      90 * 10**30,
      true,
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 274031 - 5000 - ((90 * 0.001) / 39000 * 1e8) - (((9.91 - 4.390243902439024390243902439024) / 39000 * 1e8) - ((90 * 0.001) / 39000 * 1e8))
    // = 274031 - 5000 - 230 - (14153 - 230)
    // = 254878 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 9.91 - 90
    // = 0 USD
    // 3. Pool's WBTC reserved should be: 0 WBTC
    // 4. Pool should make:
    // = 969 + 230
    // = 1199 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 254878 * 39000 / 1e8
    // = 99.40242 USD
    // 6. Pool's AUM by max price should be:
    // = 254878 * 39000 / 1e8
    // = 99.40242 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 254878);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1199);
    assertEq(poolGetterFacet.getAumE18(false), 99.40242 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.40242 * 10**18);

    // Assert position. Everything should be zero.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.primaryAccount, address(0));

    // Assert position's owner WBTC balance
    // It should be:
    // = (((9.91 - 4.390243902439024390243902439024) / 39000 * 1e8) - ((90 * 0.001) / 39000 * 1e8))
    // = 13922 sats
    assertEq(wbtc.balanceOf(address(this)), 13922);
  }

  function testCorrectness_WhenShort_WhenProfitable_WhenClosePosition_WhenStrategyProfit()
    external
  {
    poolAdminFacet.setMintBurnFeeBps(4);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    // Set strategy target bps for DAI to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);
    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // Add 100 DAI as a liquidity to the pool
    dai.mint(address(poolDiamond), 100 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Add 1 WBTC as a liquidity to the pool
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Call farm to deploy funds 0.9996 * 50% = 0.4998 WBTC
    poolFarmFacet.farm(address(wbtc), true);
    // Call farm to deploy funds 99.96 * 50% = 49.98 DAI
    poolFarmFacet.farm(address(dai), true);

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 40000) = 40083.96 USD
    // 2. Pool's AUM by max price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 41000) = 41083.56 USD
    // 3. WBTC left in the pool will be 1 - 0.4998 = 0.5002
    // 3. DAI left in the pool will be 100 - 49.98 = 50.02
    assertEq(poolGetterFacet.getAumE18(false), 40083.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41083.56 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(wbtc)), 0.5002 * 10**8);
    assertEq(poolGetterFacet.totalOf(address(dai)), 50.02 * 10**18);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Assuming DAI vault profits 100 DAI
    dai.mint(address(mockDaiVault), 100 * 10**18);

    // Open a new short position
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 99.96 + 100 [from strategy profit] + 2 WEI from share to value = 199.96000000000000002 DAI
    // 2. Pool should makes:
    // = (100 * 0.0004) + (90 * 0.001)
    // = 0.13 DAI
    // 3. Pool's DAI reserved amount should be: 90 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's AUM by min price should remain the same
    // As there is no price diff between min price and short avg price:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 40000) + 100 [from strategy profit] = 40183.96 USD
    // 6. Pool's AUM by max price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 41000) + 100 [from strategy profit] + (90 * (41000 - 40000) / 40000) [short is at loss] = 41185.81 USD
    assertEq(
      poolGetterFacet.liquidityOf(address(dai)),
      199.960000000000000002 * 10**18
    );
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.13 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 40183.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41185.81 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 10 - (90 * 0.001)
    // = 9.91 USD
    // 3. Position's average price should be:
    // = 40000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 100 DAI.
    // 5. Position's realized PnL should be 0.
    // 6. Position's should profitable as realized PnL is 0.
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Feeds WBTC@36000 USD 3 times
    wbtcPriceFeed.setLatestAnswer(36_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 36000) / 40000)
    // = 9 USD
    // 2. Position should be profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      90817
    );

    // Close position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      90 * 10**30,
      false,
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be:
    // = 99.96 - 9 [Short profit] + 100 [from strategy profit]
    // = 190.96 DAI
    // 2. Pool should makes:
    // = 0.13 + (90 * 0.001)
    // = 0.22 DAI
    // 3. Pool's DAI reserved amount should be: 0 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's WBTC short size should be 0
    // 6. Pool's WBTC short average price should be 0 USD
    // 7. Pool's AUM by min price should be:
    // = 99.96 + (90 * (36000-40000) / 40000) + (1 * (1-0.0004) * 36000) + 100 [from strategy profit]
    // = 36176.56
    // 8. Pool's AUM by max price should be:
    // = 99.96 + (90 * (36000-40000) / 40000) + (1 * (1-0.0004) * 36000) + 100 [from strategy profit]
    // = 36176.56 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 190.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.22 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 0);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.shortAveragePriceOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 36176.56 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 36176.56 * 10**18);

    // Assert position. Everything should be reset.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.primaryAccount, address(0));
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Assert receiver's DAI balance:
    // = 9.91 - 0.09 + 9
    // = 18.82 DAI
    assertEq(dai.balanceOf(address(this)), 18.82 * 10**18);
  }

  function testCorrectness_WhenShort_WhenProfitable_WhenClosePosition_WhenStrategyLoss()
    external
  {
    poolAdminFacet.setMintBurnFeeBps(4);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    // Set strategy target bps for DAI to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);
    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // Add 100 DAI as a liquidity to the pool
    dai.mint(address(poolDiamond), 100 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Add 1 WBTC as a liquidity to the pool
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Call farm to deploy funds 0.9996 * 50% = 0.4998 WBTC
    poolFarmFacet.farm(address(wbtc), true);
    // Call farm to deploy funds 99.96 * 50% = 49.98 DAI
    poolFarmFacet.farm(address(dai), true);

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 40000) = 40083.96 USD
    // 2. Pool's AUM by max price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 41000) = 41083.56 USD
    // 3. WBTC left in the pool will be 1 - 0.4998 = 0.5002
    // 3. DAI left in the pool will be 100 - 49.98 = 50.02
    assertEq(poolGetterFacet.getAumE18(false), 40083.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41083.56 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(wbtc)), 0.5002 * 10**8);
    assertEq(poolGetterFacet.totalOf(address(dai)), 50.02 * 10**18);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Assuming DAI vault lost 5 DAI
    dai.burn(address(mockDaiVault), 5 * 10**18);

    // Open a new short position
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 99.96 - 5 [from strategy loss] = 94.96 DAI
    // 2. Pool should makes:
    // = (100 * 0.0004) + (90 * 0.001)
    // = 0.13 DAI
    // 3. Pool's DAI reserved amount should be: 90 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's AUM by min price should remain the same
    // As there is no price diff between min price and short avg price:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 40000) - 5 [from strategy loss] = 40078.96 USD
    // 6. Pool's AUM by max price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 41000) - 5 [from strategy loss] + (90 * (41000 - 40000) / 40000) [short is at loss] = 41080.81 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 94.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.13 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 40078.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41080.81 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 10 - (90 * 0.001)
    // = 9.91 USD
    // 3. Position's average price should be:
    // = 40000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 100 DAI.
    // 5. Position's realized PnL should be 0.
    // 6. Position's should profitable as realized PnL is 0.
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Feeds WBTC@36000 USD 3 times
    wbtcPriceFeed.setLatestAnswer(36_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 36000) / 40000)
    // = 9 USD
    // 2. Position should be profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      90817
    );

    // Close position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      90 * 10**30,
      false,
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be:
    // = 99.96 - 9 [Short profit] - 5 [from strategy loss]
    // = 85.96 DAI
    // 2. Pool should makes:
    // = 0.13 + (90 * 0.001)
    // = 0.22 DAI
    // 3. Pool's DAI reserved amount should be: 0 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's WBTC short size should be 0
    // 6. Pool's WBTC short average price should be 0 USD
    // 7. Pool's AUM by min price should be:
    // = 99.96 + (90 * (36000-40000) / 40000) + (1 * (1-0.0004) * 36000) - 5 [from strategy loss]
    // = 36071.56
    // 8. Pool's AUM by max price should be:
    // = 99.96 + (90 * (36000-40000) / 40000) + (1 * (1-0.0004) * 36000) - 5 [from strategy loss]
    // = 36071.56 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 85.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.22 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 0);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.shortAveragePriceOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 36071.56 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 36071.56 * 10**18);

    // Assert position. Everything should be reset.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.primaryAccount, address(0));
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Assert receiver's DAI balance:
    // = 9.91 - 0.09 + 9
    // = 18.82 DAI
    assertEq(dai.balanceOf(address(this)), 18.82 * 10**18);
  }

  function testCorrectness_WhenShort_WhenLoss_WhenClosePosition_WhenStrategyProfit()
    external
  {
    poolAdminFacet.setMintBurnFeeBps(4);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    // Set strategy target bps for DAI to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);
    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // Add 100 DAI as a liquidity to the pool
    dai.mint(address(poolDiamond), 100 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Add 1 WBTC as a liquidity to the pool
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Call farm to deploy funds 0.9996 * 50% = 0.4998 WBTC
    poolFarmFacet.farm(address(wbtc), true);
    // Call farm to deploy funds 99.96 * 50% = 49.98 DAI
    poolFarmFacet.farm(address(dai), true);

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 40000) = 40083.96 USD
    // 2. Pool's AUM by max price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 41000) = 41083.56 USD
    // 3. WBTC left in the pool will be 1 - 0.4998 = 0.5002
    // 3. DAI left in the pool will be 100 - 49.98 = 50.02
    assertEq(poolGetterFacet.getAumE18(false), 40083.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41083.56 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(wbtc)), 0.5002 * 10**8);
    assertEq(poolGetterFacet.totalOf(address(dai)), 50.02 * 10**18);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Assuming DAI vault profits 100 DAI
    dai.mint(address(mockDaiVault), 100 * 10**18);

    // Open a new short position
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 99.96 + 100 [from strategy profit] + 2 WEI from share to value = 199.96000000000000002 DAI
    // 2. Pool should makes:
    // = (100 * 0.0004) + (90 * 0.001)
    // = 0.13 DAI
    // 3. Pool's DAI reserved amount should be: 90 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's AUM by min price should remain the same
    // As there is no price diff between min price and short avg price:
    // = 99.96 + + (1 * (1-0.0004) * 40000) + 100 [from strategy profit] = 40183.96 USD
    // 6. Pool's AUM by max price should be:
    // = 99.96 + (1 * (1-0.0004) * 41000) + 100 [from strategy profit] + (90 * (41000 - 40000) / 40000) [short is at loss] = 41185.81 USD
    assertEq(
      poolGetterFacet.liquidityOf(address(dai)),
      199.960000000000000002 * 10**18
    );
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.13 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 40183.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41185.81 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 10 - (90 * 0.001)
    // = 9.91 USD
    // 3. Position's average price should be:
    // = 40000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 100 DAI.
    // 5. Position's realized PnL should be 0.
    // 6. Position's should profitable as realized PnL is 0.
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Feeds WBTC@41000 USD 3 times
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * (40000 - 41000) / 40000
    // = -2.25 USD
    // 2. Position should be loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 2.25 * 10**30);
    assertTrue(!isProfit);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      90817
    );

    // Close position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      90 * 10**30,
      false,
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be:
    // = 99.96 + 2.25 [Short loss] + 100 [from strategy profit]
    // = 202.21 DAI
    // 2. Pool should makes:
    // = 0.13 + (90 * 0.001)
    // = 0.22 DAI
    // 3. Pool's DAI reserved amount should be: 0 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's WBTC short size should be 0
    // 6. Pool's WBTC short average price should be 0 USD
    // 7. Pool's AUM by min price should be:
    // = 99.96 + (90 * (41000-40000) / 40000) + (1 * (1-0.0004) * 41000) + 100 [from strategy profit]
    // = 41185.81 USD
    // 8. Pool's AUM by max price should be:
    // = 99.96 + (90 * (41000-40000) / 40000) + (1 * (1-0.0004) * 41000) + 100 [from strategy profit]
    // = 41185.81 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 202.21 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.22 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 0);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.shortAveragePriceOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 41185.81 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41185.81 * 10**18);

    // Assert position. Everything should be reset.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.primaryAccount, address(0));
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Assert receiver's DAI balance:
    // = 9.91 - 0.09 - 2.25
    // = 18.82 DAI
    assertEq(dai.balanceOf(address(this)), 7.57 * 10**18);
  }

  function testCorrectness_WhenShort_WhenLoss_WhenClosePosition_WhenStrategyLoss()
    external
  {
    poolAdminFacet.setMintBurnFeeBps(4);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    // Set strategy target bps for DAI to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);
    // Set strategy target bps for WBTC to be 50%
    poolFarmFacet.setStrategyTargetBps(address(wbtc), 5000);

    // Add 100 DAI as a liquidity to the pool
    dai.mint(address(poolDiamond), 100 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Add 1 WBTC as a liquidity to the pool
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Call farm to deploy funds 0.9996 * 50% = 0.4998 WBTC
    poolFarmFacet.farm(address(wbtc), true);
    // Call farm to deploy funds 99.96 * 50% = 49.98 DAI
    poolFarmFacet.farm(address(dai), true);

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 40000) = 40083.96 USD
    // 2. Pool's AUM by max price should be:
    // = (100 * (1-0.0004)) + (1 * (1-0.0004) * 41000) = 41083.56 USD
    // 3. WBTC left in the pool will be 1 - 0.4998 = 0.5002
    // 3. DAI left in the pool will be 100 - 49.98 = 50.02
    assertEq(poolGetterFacet.getAumE18(false), 40083.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41083.56 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(wbtc)), 0.5002 * 10**8);
    assertEq(poolGetterFacet.totalOf(address(dai)), 50.02 * 10**18);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Assuming DAI vault lost 5 DAI
    dai.burn(address(mockDaiVault), 5 * 10**18);

    // Open a new short position
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 99.96 + 5 [from strategy loss] = 94.96 DAI
    // 2. Pool should makes:
    // = (100 * 0.0004) + (90 * 0.001)
    // = 0.13 DAI
    // 3. Pool's DAI reserved amount should be: 90 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's AUM by min price should remain the same
    // As there is no price diff between min price and short avg price:
    // = 99.96 + + (1 * (1-0.0004) * 40000) + 5 [from strategy loss] = 40078.96 USD
    // 6. Pool's AUM by max price should be:
    // = 99.96 + (1 * (1-0.0004) * 41000) + 5 [from strategy loss] + (90 * (41000 - 40000) / 40000) [short is at loss] = 41080.81 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 94.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.13 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 40078.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41080.81 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 10 - (90 * 0.001)
    // = 9.91 USD
    // 3. Position's average price should be:
    // = 40000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 100 DAI.
    // 5. Position's realized PnL should be 0.
    // 6. Position's should profitable as realized PnL is 0.
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Feeds WBTC@41000 USD 3 times
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * (40000 - 41000) / 40000
    // = -2.25 USD
    // 2. Position should be loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 2.25 * 10**30);
    assertTrue(!isProfit);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      90817
    );

    // Close position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      90 * 10**30,
      false,
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be:
    // = 99.96 + 2.25 [Short loss] - 5 [from strategy loss]
    // = 97.21 DAI
    // 2. Pool should makes:
    // = 0.13 + (90 * 0.001)
    // = 0.22 DAI
    // 3. Pool's DAI reserved amount should be: 0 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's WBTC short size should be 0
    // 6. Pool's WBTC short average price should be 0 USD
    // 7. Pool's AUM by min price should be:
    // = 99.96 + (90 * (41000-40000) / 40000) + (1 * (1-0.0004) * 41000) - 5 [from strategy loss]
    // = 41080.81 USD
    // 8. Pool's AUM by max price should be:
    // = 99.96 + (90 * (41000-40000) / 40000) + (1 * (1-0.0004) * 41000) - 5 [from strategy loss]
    // = 41080.81 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 97.21 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.22 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 0);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.shortAveragePriceOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 41080.81 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 41080.81 * 10**18);

    // Assert position. Everything should be reset.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.primaryAccount, address(0));
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Assert receiver's DAI balance:
    // = 9.91 - 0.09 - 2.25
    // = 18.82 DAI
    assertEq(dai.balanceOf(address(this)), 7.57 * 10**18);
  }
}
