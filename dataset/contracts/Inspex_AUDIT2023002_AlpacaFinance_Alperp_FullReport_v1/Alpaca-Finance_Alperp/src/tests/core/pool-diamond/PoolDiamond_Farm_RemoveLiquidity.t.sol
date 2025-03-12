// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, LibPoolConfigV1, MockDonateVault, MockStrategy, console, GetterFacetInterface, LiquidityFacetInterface, stdError } from "./PoolDiamond_BaseTest.t.sol";
import { StrategyInterface } from "src/interfaces/StrategyInterface.sol";

contract PoolDiamond_Farm_RemoveLiquidityTest is PoolDiamond_BaseTest {
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

  function testCorrectness_WhenRemoveLiquidity_WhenProfit_WhenEnoughBalanceInPool()
    external
  {
    // Set strategy target bps to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);

    // Add 1000 DAI to the pool
    dai.mint(address(poolDiamond), 1000 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 1000 * (1-0.003)
    // = 997 DAI
    // 2. Pool's aum by min price should be:
    // = 997 * 1
    // = 997 USD
    // 3. Pool's aum by max price should be:
    // = 997 * 1
    // = 997 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 997 * 10**18);

    // Call farm to deploy funds 997 * 50% = 498.5 DAI
    poolFarmFacet.farm(address(dai), true);

    // The following conditions should be met:
    // 1. DAI's liquidity should be: 997 DAI
    // 2. DAI's strategy principle should be: 498.5 DAI
    // 3. Pool's aum by min price should be:
    // = 997 * 1 + 0 [StrategyDelta]
    // = 997 USD
    // 4. Pool's aum by max price should be:
    // = 997 * 1 + 0 [StrategyDelta]
    // = 997 USD
    // 5. Pool's total DAI should be 1000 - 498.5 =  501.5 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 997 * 10**18);
    assertEq(
      poolGetterFacet.strategyDataOf(address(dai)).principle,
      498.5 * 10**18
    );
    assertEq(poolGetterFacet.getAumE18(false), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 997 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(dai)), 501.5 * 10**18);

    // Assuming profit 20 DAI
    dai.mint(address(mockDaiVault), 20 * 10**18);

    // The following conditions should be met:
    // 1. DAI's strategy delta should be: 20 DAI
    // 2. DAI's strategy should be profitable
    // 3. Pool's aum by min price should be:
    // = 997 * 1 + 20 [StrategyDelta]
    // = 1017 USD
    // 4. Pool's aum by max price should be:
    // = 997 * 1 + 20 [StrategyDelta]
    // = 1017 USD
    (bool isProfit, uint256 strategyDelta) = poolGetterFacet.getStrategyDeltaOf(
      address(dai)
    );
    assertEq(strategyDelta, 20 * 10**18);
    assertTrue(isProfit);
    assertEq(poolGetterFacet.getAumE18(false), 1017 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 1017 * 10**18);

    // Warp to pass liquidity cool down
    vm.warp(block.timestamp + 1 days);

    // Remove 400 DAI from the pool
    alp.transfer(
      address(poolDiamond),
      (400 ether * alp.totalSupply()) / poolGetterFacet.getAumE18(false)
    );
    poolLiquidityFacet.removeLiquidity(
      address(this),
      address(dai),
      address(this)
    );

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 997 + 20 - 400
    // = 617 DAI
    // 2. DAI's strategy principle should be: 498.5 DAI
    // 3. Pool's aum by min price should be:
    // = 617 * 1 + 0 [StrategyDelta]
    // = 617
    // 4. Pool's aum by max price should be:
    // = 617 * 1 + 0 [StrategyDelta]
    // = 617
    // 5. address(this) should received:
    // = 400 * (1-0.003)
    // = 398.8 DAI
    // 6. Pool should make:
    // = 3 + (400 * 0.003)
    // = 4.2 DAI
    // 7. Pool's total DAI should be:
    // = 1000 - 498.5 + 20 - 398.8
    // = 122.7 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 617 * 10**18 + 1);
    assertEq(
      poolGetterFacet.strategyDataOf(address(dai)).principle,
      498.5 * 10**18
    );
    assertEq(poolGetterFacet.getAumE18(false), 617 * 10**18 + 1);
    assertEq(poolGetterFacet.getAumE18(true), 617 * 10**18 + 1);
    assertEq(dai.balanceOf(address(this)), 398.8 * 10**18 - 1);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 4.2 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(dai)), 122.7 * 10**18 + 1);
  }

  function testCorrectness_WhenRemoveLiquidity_WhenProfit_WhenNotEnoughBalanceInPool()
    external
  {
    // Set strategy target bps to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);

    // Add 1000 DAI to the pool
    dai.mint(address(poolDiamond), 1000 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 1000 * (1-0.003)
    // = 997 DAI
    // 2. Pool's aum by min price should be:
    // = 997 * 1
    // = 997 USD
    // 3. Pool's aum by max price should be:
    // = 997 * 1
    // = 997 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 997 * 10**18);

    // Call farm to deploy funds 997 * 50% = 498.5 DAI
    poolFarmFacet.farm(address(dai), true);

    // The following conditions should be met:
    // 1. DAI's liquidity should be: 997 DAI
    // 2. DAI's strategy principle should be: 498.5 DAI
    // 3. Pool's aum by min price should be:
    // = 997 * 1 + 0 [StrategyDelta]
    // = 997 USD
    // 4. Pool's aum by max price should be:
    // = 997 * 1 + 0 [StrategyDelta]
    // = 997 USD
    // 5. Pool's total DAI should be 1000 - 498.5 =  501.5 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 997 * 10**18);
    assertEq(
      poolGetterFacet.strategyDataOf(address(dai)).principle,
      498.5 * 10**18
    );
    assertEq(poolGetterFacet.getAumE18(false), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 997 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(dai)), 501.5 * 10**18);

    // Assuming profit 20 DAI
    dai.mint(address(mockDaiVault), 20 * 10**18);

    // The following conditions should be met:
    // 1. DAI's strategy delta should be: 20 DAI
    // 2. DAI's strategy should be profitable
    // 3. Pool's aum by min price should be:
    // = 997 * 1 + 20 [StrategyDelta]
    // = 1017 USD
    // 4. Pool's aum by max price should be:
    // = 997 * 1 + 20 [StrategyDelta]
    // = 1017 USD
    (bool isProfit, uint256 strategyDelta) = poolGetterFacet.getStrategyDeltaOf(
      address(dai)
    );
    assertEq(strategyDelta, 20 * 10**18);
    assertTrue(isProfit);
    assertEq(poolGetterFacet.getAumE18(false), 1017 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 1017 * 10**18);

    // Warp to pass liquidity cool down
    vm.warp(block.timestamp + 1 days);

    // Remove 600 DAI from the pool
    alp.transfer(
      address(poolDiamond),
      (600 ether * alp.totalSupply()) / poolGetterFacet.getAumE18(false)
    );
    poolLiquidityFacet.removeLiquidity(
      address(this),
      address(dai),
      address(this)
    );

    (isProfit, strategyDelta) = poolGetterFacet.getStrategyDeltaOf(
      address(dai)
    );

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 997 + 20 - 600
    // = 417 DAI
    // 2. DAI's strategy principle should be:
    // = 498.5 - ((600 * (1-0.003)) [AmountOut] - (501.5 [BalanceBeforeRemoveLiq] + 20 [StrategyDelta] - (3 + 1.8 [FeeReserve])))
    // = 498.5 - 81.5
    // = 417 DAI
    // 3. Pool's aum by min price should be:
    // = 417 * 1 + 0 [StrategyDelta]
    // = 417
    // 4. Pool's aum by max price should be:
    // = 417 * 1 + 0 [StrategyDelta]
    // = 417
    // 5. address(this) should received:
    // = 600 * (1-0.003)
    // = 598.2 DAI
    // 6. Pool should make:
    // = 3 + (600 * 0.003)
    // = 4.8 DAI
    // 7. Pool's total DAI should be: 4.8 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 417 * 10**18 + 1);
    assertEq(
      poolGetterFacet.strategyDataOf(address(dai)).principle,
      417 * 10**18 + 1
    );
    assertEq(poolGetterFacet.getAumE18(false), 417 * 10**18 + 1);
    assertEq(poolGetterFacet.getAumE18(true), 417 * 10**18 + 1);
    assertEq(dai.balanceOf(address(this)), 598.2 * 10**18 - 1);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 4.8 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(dai)), 4.8 * 10**18);
  }

  function testCorrectness_WhenRemoveLiquidity_WhenLoss_WhenEnoughBalanceInPool()
    external
  {
    // Set strategy target bps to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);

    // Add 1000 DAI to the pool
    dai.mint(address(poolDiamond), 1000 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 1000 * (1-0.003)
    // = 997 DAI
    // 2. Pool's aum by min price should be:
    // = 997 * 1
    // = 997 USD
    // 3. Pool's aum by max price should be:
    // = 997 * 1
    // = 997 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 997 * 10**18);

    // Call farm to deploy funds 997 * 50% = 498.5 DAI
    poolFarmFacet.farm(address(dai), true);

    // The following conditions should be met:
    // 1. DAI's liquidity should be: 997 DAI
    // 2. DAI's strategy principle should be: 498.5 DAI
    // 3. Pool's aum by min price should be:
    // = 997 * 1 + 0 [StrategyDelta]
    // = 997 USD
    // 4. Pool's aum by max price should be:
    // = 997 * 1 + 0 [StrategyDelta]
    // = 997 USD
    // 5. Pool's total DAI should be 1000 - 498.5 =  501.5 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 997 * 10**18);
    assertEq(
      poolGetterFacet.strategyDataOf(address(dai)).principle,
      498.5 * 10**18
    );
    assertEq(poolGetterFacet.getAumE18(false), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 997 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(dai)), 501.5 * 10**18);

    // Assuming loss 20 DAI
    dai.burn(address(mockDaiVault), 20 * 10**18);

    // The following conditions should be met:
    // 1. DAI's strategy delta should be: -20 DAI
    // 2. DAI's strategy should be loss
    // 3. Pool's aum by min price should be:
    // = 997 * 1 - 20 [StrategyDelta]
    // = 977 USD
    // 4. Pool's aum by max price should be:
    // = 997 * 1 - 20 [StrategyDelta]
    // = 977 USD
    (bool isProfit, uint256 strategyDelta) = poolGetterFacet.getStrategyDeltaOf(
      address(dai)
    );
    assertEq(strategyDelta, 20 * 10**18);
    assertTrue(!isProfit);
    assertEq(poolGetterFacet.getAumE18(false), 977 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 977 * 10**18);

    // Warp to pass liquidity cool down
    vm.warp(block.timestamp + 1 days);

    // Remove 400 DAI from the pool
    alp.transfer(
      address(poolDiamond),
      (400 ether * alp.totalSupply()) / poolGetterFacet.getAumE18(false)
    );
    poolLiquidityFacet.removeLiquidity(
      address(this),
      address(dai),
      address(this)
    );

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 997 - 20 - 400
    // = 577 DAI
    // 2. DAI's strategy principle should be:
    // = 498.5 - 20
    // = 478.5 DAI
    // 3. Pool's aum by min price should be:
    // = 577 * 1 + 0 [StrategyDelta]
    // = 577
    // 4. Pool's aum by max price should be:
    // = 577 * 1 + 0 [StrategyDelta]
    // = 577
    // 5. address(this) should received:
    // = 400 * (1-0.003)
    // = 398.8 DAI
    // 6. Pool should make:
    // = 3 + (400 * 0.003)
    // = 4.2 DAI
    // 7. Pool's total DAI should be:
    // = 1000 - 498.5 - 398.8
    // = 102.7 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 577 * 10**18 + 1);
    assertEq(
      poolGetterFacet.strategyDataOf(address(dai)).principle,
      478.5 * 10**18
    );
    assertEq(poolGetterFacet.getAumE18(false), 577 * 10**18 + 1);
    assertEq(poolGetterFacet.getAumE18(true), 577 * 10**18 + 1);
    assertEq(dai.balanceOf(address(this)), 398.8 * 10**18 - 1);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 4.2 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(dai)), 102.7 * 10**18 + 1);

    // Exit position
    uint256 daiBefore = dai.balanceOf(address(this));
    alp.transfer(address(poolDiamond), alp.balanceOf(address(this)));
    poolLiquidityFacet.removeLiquidity(
      address(this),
      address(dai),
      address(this)
    );
    uint256 daiAfter = dai.balanceOf(address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be: 0
    // 2. DAI's strategy principle should be: 0
    // 3. Pool's aum by min price should be: 0
    // 4. Pool's aum by max price should be: 0
    // 5. address(this) should received:
    // = 577 * (1-0.003)
    // = 575.269 DAI
    // 6. Pool should make:
    // = 4.2 + (577 * 0.003)
    // = 5.931 DAI
    // 7. Pool's total DAI should be:
    // = 5.931 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 0);
    assertEq(poolGetterFacet.strategyDataOf(address(dai)).principle, 0);
    assertEq(poolGetterFacet.getAumE18(false), 0);
    assertEq(poolGetterFacet.getAumE18(true), 0);
    assertEq(daiAfter - daiBefore, 575.269 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 5.931 * 10**18 + 1);
    assertEq(poolGetterFacet.totalOf(address(dai)), 5.931 * 10**18 + 1);
  }

  function testCorrectness_WhenRemoveLiquidity_WhenLoss_WhenNotEnoughBalanceInPool()
    external
  {
    // Set strategy target bps to be 50%
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);

    // Add 1000 DAI to the pool
    dai.mint(address(poolDiamond), 1000 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 1000 * (1-0.003)
    // = 997 DAI
    // 2. Pool's aum by min price should be:
    // = 997 * 1
    // = 997 USD
    // 3. Pool's aum by max price should be:
    // = 997 * 1
    // = 997 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 997 * 10**18);

    // Call farm to deploy funds 997 * 50% = 498.5 DAI
    poolFarmFacet.farm(address(dai), true);

    // The following conditions should be met:
    // 1. DAI's liquidity should be: 997 DAI
    // 2. DAI's strategy principle should be: 498.5 DAI
    // 3. Pool's aum by min price should be:
    // = 997 * 1 + 0 [StrategyDelta]
    // = 997 USD
    // 4. Pool's aum by max price should be:
    // = 997 * 1 + 0 [StrategyDelta]
    // = 997 USD
    // 5. Pool's total DAI should be 1000 - 498.5 =  501.5 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 997 * 10**18);
    assertEq(
      poolGetterFacet.strategyDataOf(address(dai)).principle,
      498.5 * 10**18
    );
    assertEq(poolGetterFacet.getAumE18(false), 997 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 997 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(dai)), 501.5 * 10**18);

    // Assuming loss 20 DAI
    dai.burn(address(mockDaiVault), 20 * 10**18);

    // The following conditions should be met:
    // 1. DAI's strategy delta should be: -20 DAI
    // 2. DAI's strategy should be loss
    // 3. Pool's aum by min price should be:
    // = 997 * 1 - 20 [StrategyDelta]
    // = 977 USD
    // 4. Pool's aum by max price should be:
    // = 997 * 1 - 20 [StrategyDelta]
    // = 977 USD
    (bool isProfit, uint256 strategyDelta) = poolGetterFacet.getStrategyDeltaOf(
      address(dai)
    );
    assertEq(strategyDelta, 20 * 10**18);
    assertTrue(!isProfit);
    assertEq(poolGetterFacet.getAumE18(false), 977 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 977 * 10**18);

    // Warp to pass liquidity cool down
    vm.warp(block.timestamp + 1 days);

    // Remove 600 DAI from the pool
    alp.transfer(
      address(poolDiamond),
      (600 ether * alp.totalSupply()) / poolGetterFacet.getAumE18(false)
    );
    poolLiquidityFacet.removeLiquidity(
      address(this),
      address(dai),
      address(this)
    );

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 997 - 20 - 600
    // = 377 DAI
    // 2. DAI's strategy principle should be:
    // = (498.5 - 20) - (598.2 - (501.5 - (1.8 + 3)))
    // = 377 DAI
    // 3. Pool's aum by min price should be:
    // = 377 * 1 + 0 [StrategyDelta]
    // = 377
    // 4. Pool's aum by max price should be:
    // = 377 * 1 + 0 [StrategyDelta]
    // = 377
    // 5. address(this) should received:
    // = 600 * (1-0.003)
    // = 598.2 DAI
    // 6. Pool should make:
    // = 3 + (600 * 0.003)
    // = 4.8 DAI
    // 7. Pool's total DAI should be:
    // = 4.8 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 377 * 10**18 + 1);
    assertEq(
      poolGetterFacet.strategyDataOf(address(dai)).principle,
      377 * 10**18 + 1
    );
    assertEq(poolGetterFacet.getAumE18(false), 377 * 10**18 + 1);
    assertEq(poolGetterFacet.getAumE18(true), 377 * 10**18 + 1);
    assertEq(dai.balanceOf(address(this)), 598.2 * 10**18 - 1);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 4.8 * 10**18);
    assertEq(poolGetterFacet.totalOf(address(dai)), 4.8 * 10**18);

    // Exit position
    uint256 daiBefore = dai.balanceOf(address(this));
    alp.transfer(address(poolDiamond), alp.balanceOf(address(this)));
    poolLiquidityFacet.removeLiquidity(
      address(this),
      address(dai),
      address(this)
    );
    uint256 daiAfter = dai.balanceOf(address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be: 0
    // 2. DAI's strategy principle should be: 0
    // 3. Pool's aum by min price should be: 0
    // 4. Pool's aum by max price should be: 0
    // 5. address(this) should received:
    // = 377 * (1-0.003)
    // = 375.869 DAI
    // 6. Pool should make:
    // = 4.8 + (377 * 0.003)
    // = 5.931 DAI
    // 7. Pool's total DAI should be:
    // = 5.931 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 0);
    assertEq(poolGetterFacet.strategyDataOf(address(dai)).principle, 0);
    assertEq(poolGetterFacet.getAumE18(false), 0);
    assertEq(poolGetterFacet.getAumE18(true), 0);
    assertEq(daiAfter - daiBefore, 375.869 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 5.931 * 10**18 + 1);
    assertEq(poolGetterFacet.totalOf(address(dai)), 5.931 * 10**18 + 1);
  }
}
