// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, LibPoolConfigV1, MockDonateVault, MockStrategy, console, GetterFacetInterface, LiquidityFacetInterface } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_SetStrategyTargetBpsTest is PoolDiamond_BaseTest {
  MockDonateVault internal mockDaiVault;
  MockStrategy internal mockDaiVaultStrategy;

  function setUp() public override {
    super.setUp();

    (
      address[] memory tokens2,
      LibPoolConfigV1.TokenConfig[] memory tokenConfigs2
    ) = buildDefaultSetTokenConfigInput2();

    poolAdminFacet.setTokenConfigs(tokens2, tokenConfigs2);

    // Feed prices
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);
  }

  function testRevert_WhenNotOwner() external {
    vm.startPrank(ALICE);

    vm.expectRevert("LibDiamond: Must be contract owner");
    poolFarmFacet.setStrategyTargetBps(address(dai), 1);

    vm.stopPrank();
  }

  function testRevert_WhenTargetBpsMoreThanMaxTargetBps() external {
    vm.expectRevert(abi.encodeWithSignature("FarmFacet_BadTargetBps()"));
    poolFarmFacet.setStrategyTargetBps(address(dai), 10001);
  }

  function testCorrectness_WhenSetStrategyTargetBpsSuccessfully() external {
    poolFarmFacet.setStrategyTargetBps(address(dai), 5000);

    LibPoolConfigV1.StrategyData memory strategyData = poolGetterFacet
      .strategyDataOf(address(dai));
    assertEq(strategyData.targetBps, 5000);
  }
}
