// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, LibPoolConfigV1, MockDonateVault, MockStrategy, console, GetterFacetInterface, LiquidityFacetInterface, stdError } from "./PoolDiamond_BaseTest.t.sol";
import { StrategyInterface } from "../../../interfaces/StrategyInterface.sol";

contract PoolDiamond_FarmTest is PoolDiamond_BaseTest {
  MockDonateVault internal mockDaiVault;
  MockStrategy internal mockDaiVaultStrategy;

  MockDonateVault internal mockWbtcVault;
  MockStrategy internal mockWbtcVaultStrategy;

  MockDonateVault internal mockMaticVault;
  MockStrategy internal mockMaticVaultStrategy;

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
    maticPriceFeed.setLatestAnswer(300 * 10**8);

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

    // MaticVault
    mockMaticVault = new MockDonateVault(address(matic));
    mockMaticVaultStrategy = new MockStrategy(
      address(matic),
      mockMaticVault,
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

    // Set and commit MATIC strategy
    poolFarmFacet.setStrategyOf(address(matic), mockMaticVaultStrategy);
    vm.warp(block.timestamp + 1 weeks + 1);
    poolFarmFacet.setStrategyOf(address(matic), mockMaticVaultStrategy);
  }

  function testRevert_WhenFarm_WhenNeitherFarmKeeper_NorPoolDiamond_IsACaller()
    external
  {
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("FarmFacet_InvalidFarmCaller()"));
    poolFarmFacet.farm(address(wbtc), true);

    vm.expectRevert(abi.encodeWithSignature("FarmFacet_InvalidFarmCaller()"));
    poolFarmFacet.farm(address(wbtc), false);
    vm.stopPrank();
  }
}
