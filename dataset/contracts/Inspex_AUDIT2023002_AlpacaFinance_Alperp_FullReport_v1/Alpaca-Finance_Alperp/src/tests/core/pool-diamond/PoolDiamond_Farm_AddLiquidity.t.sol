// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, LibPoolConfigV1, MockDonateVault, MockStrategy, console, GetterFacetInterface, LiquidityFacetInterface, stdError } from "./PoolDiamond_BaseTest.t.sol";
import { StrategyInterface } from "src/interfaces/StrategyInterface.sol";

contract PoolDiamond_Farm_AddLiquidityTest is PoolDiamond_BaseTest {
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

  function testCorrectness_WhenAddLiquidity_WhenProfit() external {
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

    // Add 2000 DAI to the pool
    dai.mint(address(poolDiamond), 2000 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 997 + 2000 * (1-0.003)
    // = 2991 DAI
    // 2. Pool's aum by min price should be:
    // = 2991 * 1
    // = 2991 USD
    // 3. Pool's aum by max price should be:
    // = 2991 * 1
    // = 2991 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 2991 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 2991 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 2991 * 10**18);

    // Assuming vault profit 10 DAI
    dai.mint(address(mockDaiVault), 10 * 10**18);

    // The following conditions should be met:
    // 1. DAI's strategy delta should be: +10 DAI
    // 2. DAI's strategy should be profitable
    // 2. Pool's aum by min price should be:
    // = 2991 * 1 + 10 [StrategyDelta]
    // = 3001 USD
    // 3. Pool's aum by max price should be:
    // = 2991 * 1 + 10 [StrategyDelta]
    // = 3001 USD
    (bool isProfit, uint256 strategyDelta) = poolGetterFacet.getStrategyDeltaOf(
      address(dai)
    );
    assertEq(strategyDelta, 10 * 10**18);
    assertTrue(isProfit);
    assertEq(poolGetterFacet.getAumE18(false), 3001 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 3001 * 10**18);

    // Add 500 DAI to the pool
    dai.mint(address(poolDiamond), 500 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 2991 + (500 * (1-0.003)) + 10 [StrategyDelta]
    // = 3499.5 DAI
    // 2. Pool's aum by min price should be:
    // = 3489.5 + 10 [StrategyDelta]
    // = 3499.5 USD
    // 3. Pool's aum by max price should be:
    // = 3489.5 + 10 [StrategyDelta]
    // = 3499.5 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 3499.5 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 3499.5 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 3499.5 * 10**18);
  }

  function testCorrectness_WhenAddLiquidity_WhenLoss() external {
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

    // Add 500 DAI to the pool
    dai.mint(address(poolDiamond), 500 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 997 + 500 * (1-0.003)
    // = 1495.5 DAI
    // 2. Pool's aum by min price should be:
    // = 1495.5 * 1
    // = 1495.5 USD
    // 3. Pool's aum by max price should be:
    // = 1495.5 * 1
    // = 1495.5 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 1495.5 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 1495.5 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 1495.5 * 10**18);

    // Assuming vault loss 20 DAI
    dai.burn(address(mockDaiVault), 20 * 10**18);

    // The following conditions should be met:
    // 1. DAI's strategy delta should be: -20 DAI
    // 2. DAI's strategy should NOT be profitable
    // 2. Pool's aum by min price should be:
    // = 1495.5 * 1 - 20 [StrategyDelta]
    // = 1475.5 USD
    // 3. Pool's aum by max price should be:
    // = 1495.5 * 1 - 20 [StrategyDelta]
    // = 1475.5 USD
    (bool isProfit, uint256 strategyDelta) = poolGetterFacet.getStrategyDeltaOf(
      address(dai)
    );
    assertEq(strategyDelta, 20 * 10**18);
    assertTrue(!isProfit);
    assertEq(poolGetterFacet.getAumE18(false), 1475.5 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 1475.5 * 10**18);

    // Add 500 DAI to the pool
    dai.mint(address(poolDiamond), 500 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions should be met:
    // 1. DAI's liquidity should be:
    // = 1495.5 + (500 * (1-0.003)) - 20 [StrategyDelta]
    // = 1974 DAI
    // 2. Pool's aum by min price should be:
    // = 1974 + 0 [StrategyDelta]
    // = 1974 USD
    // 3. Pool's aum by max price should be:
    // = 1974 + 0 [StrategyDelta]
    // = 1974 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 1974 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 1974 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 1974 * 10**18);
  }
}
