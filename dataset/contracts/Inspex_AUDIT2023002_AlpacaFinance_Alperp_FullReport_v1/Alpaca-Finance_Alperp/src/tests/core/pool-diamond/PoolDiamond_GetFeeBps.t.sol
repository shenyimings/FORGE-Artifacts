// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, console, LibPoolConfigV1, LiquidityFacetInterface, GetterFacetInterface, PerpTradeFacetInterface } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_GetFeeBpsTest is PoolDiamond_BaseTest {
  function setUp() public override {
    super.setUp();

    address[] memory tokens = new address[](1);
    tokens[0] = address(bnb);

    LibPoolConfigV1.TokenConfig[]
      memory tokenConfigs = new LibPoolConfigV1.TokenConfig[](1);
    tokenConfigs[0] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: true,
      decimals: bnb.decimals(),
      weight: 10000,
      minProfitBps: 75,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });

    poolAdminFacet.setTokenConfigs(tokens, tokenConfigs);
  }

  function testCorrectness_GetFeeBps() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Set Mint Burn Fee Bps to 20 BPS
    poolAdminFacet.setMintBurnFeeBps(20);

    // Turn on dynamic fee
    poolAdminFacet.setIsDynamicFeeEnable(true);

    // Add 100 wei of BNB as a liquidity
    bnb.mint(address(poolDiamond), 100);
    poolLiquidityFacet.addLiquidity(address(this), address(bnb), address(this));

    // The following conditions are expected to be true:
    // 1. Pool's BNB USD debt should be:
    // = math.trunc(100 * (1-0.002)) * 300
    // = 29700
    // 2. Pool's BNB target value should be:
    // = 29700 * 10000 / 10000
    // = 29700
    assertEq(poolGetterFacet.usdDebtOf(address(bnb)), 29700);
    assertEq(poolGetterFacet.getTargetValue(address(bnb)), 29700);

    // BNB's USD value is 29700, and the target value is 29700
    // Assuming:
    // 1. mintBurnFeeBps is 100 BPS
    // 2. taxBps is 50 BPS
    poolAdminFacet.setMintBurnFeeBps(100);
    poolAdminFacet.setTaxBps(50, 50);

    // Assert with the given conditions.
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 1000), 100);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 5000), 104);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 1000), 100);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 5000), 104);

    // Assuming:
    // 1. mintBurnFeeBps is 50 BPS
    // 2. taxBps is 100 BPS
    poolAdminFacet.setMintBurnFeeBps(50);
    poolAdminFacet.setTaxBps(100, 100);

    // Assert with the given conditions.
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 1000), 51);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 5000), 58);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 1000), 51);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 5000), 58);

    // Add DAI to the allow token list
    address[] memory tokens = new address[](1);
    tokens[0] = address(dai);
    LibPoolConfigV1.TokenConfig[]
      memory tokenConfigs = new LibPoolConfigV1.TokenConfig[](1);
    tokenConfigs[0] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: true,
      isShortable: false,
      decimals: dai.decimals(),
      weight: 10000,
      minProfitBps: 75,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });
    poolAdminFacet.setTokenConfigs(tokens, tokenConfigs);

    // Assert target value.
    // 1. Pool's BNB target value should be:
    // = 29700 * 10000 / 20000
    // = 14850
    // 2. Pool's DAI target value should be:
    // = 29700 * 10000 / 20000
    // = 14850
    assertEq(poolGetterFacet.getTargetValue(address(bnb)), 14850);
    assertEq(poolGetterFacet.getTargetValue(address(dai)), 14850);

    // BNB's USD value is 29700, and the target value is 14850
    // Assuming:
    // 1. mintBurnFeeBps is 100 BPS
    // 2. taxBps is 50 BPS
    poolAdminFacet.setMintBurnFeeBps(100);
    poolAdminFacet.setTaxBps(50, 50);

    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 1000), 150);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 5000), 150);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 10000), 150);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 20000), 150);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 1000), 50);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 5000), 50);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 10000), 50);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 20000), 50);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 25000), 50);
    assertEq(
      poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 100000),
      150
    );

    // Assuming:
    // 1. mintBurnFeeBps is 20 BPS
    // 2. taxBps is 50 BPS
    // 3. stableTaxBps is 10 BPS
    poolAdminFacet.setMintBurnFeeBps(20);
    poolAdminFacet.setTaxBps(50, 10);

    // Add 20000 wei of DAI as a liquidity
    dai.mint(address(poolDiamond), 20000);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Assert target value.
    assertEq(poolGetterFacet.getTargetValue(address(bnb)), 24850);
    assertEq(poolGetterFacet.getTargetValue(address(dai)), 24850);

    // Adjust BNB's token weight
    tokens[0] = address(bnb);
    tokenConfigs[0] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: true,
      decimals: bnb.decimals(),
      weight: 30000,
      minProfitBps: 75,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });
    poolAdminFacet.setTokenConfigs(tokens, tokenConfigs);

    // Assert target value
    assertEq(poolGetterFacet.getTargetValue(address(bnb)), 37275);
    assertEq(poolGetterFacet.getTargetValue(address(dai)), 12425);

    // Assert BNB's USD debt should be the same
    assertEq(poolGetterFacet.usdDebtOf(address(bnb)), 29700);

    // BNB's USD value is 29700, and the target value is 37275
    // Add more BNB to the pool, low fee
    // Remove BNB from the pool, high fee
    // Assuming:
    // 1. mintBurnFeeBps is 100 BPS
    // 2. taxBps is 50 BPS
    // 3. stableTaxBps is 10 BPS
    poolAdminFacet.setMintBurnFeeBps(100);
    poolAdminFacet.setTaxBps(50, 10);

    // Assert add liquidity fee, should be low fee
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 1000), 90);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 5000), 90);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 10000), 90);

    // Assert remove liquidity fee, should be high fee
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 1000), 110);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 5000), 113);
    assertEq(
      poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 10000),
      116
    );

    // Set fee back to what I should be.
    // 1. mintBurnFeeBps is 20 BPS
    // 2. taxBps is 50 BPS
    // 3. stableTaxBps is 10 BPS
    poolAdminFacet.setMintBurnFeeBps(20);
    poolAdminFacet.setTaxBps(50, 10);

    // Reduce BNB's token weight to 5000
    tokenConfigs[0].weight = 5000;
    poolAdminFacet.setTokenConfigs(tokens, tokenConfigs);

    // Add 200 wei of BNB as a liquidity
    bnb.mint(address(poolDiamond), 200);
    poolLiquidityFacet.addLiquidity(address(this), address(bnb), address(this));

    // Assert USD debt and target value
    assertEq(poolGetterFacet.usdDebtOf(address(bnb)), 89100);
    assertEq(poolGetterFacet.getTargetValue(address(bnb)), 36366);
    assertEq(poolGetterFacet.getTargetValue(address(dai)), 72733);

    // BNB's USD value is 89100, and the target value is 36366
    // Add more BNB to the pool, high fee
    // Remove BNB from the pool, low fee
    // Assuming:
    // 1. mintBurnFeeBps is 100 BPS
    // 2. taxBps is 50 BPS
    // 3. stableTaxBps is 10 BPS
    poolAdminFacet.setMintBurnFeeBps(100);
    poolAdminFacet.setTaxBps(50, 10);

    // Assert add liquidity, result in high fee
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 1000), 150);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 5000), 150);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 10000), 150);

    // Assert remove liquidity, result in lower fee
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 1000), 28);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 5000), 28);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 20000), 28);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 50000), 28);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 80000), 28);

    // Assuming:
    // 1. mintBurnFeeBps is 50 BPS
    // 2. taxBps is 100 BPS
    // 3. stableTaxBps is 10 BPS
    poolAdminFacet.setMintBurnFeeBps(50);
    poolAdminFacet.setTaxBps(100, 10);

    // Assert add liquidity, result in high fee
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 1000), 150);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 5000), 150);
    assertEq(poolGetterFacet.getAddLiquidityFeeBps(address(bnb), 10000), 150);

    // Assert remove liquidity, result in lower fee
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 1000), 0);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 5000), 0);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 20000), 0);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 50000), 0);
    assertEq(poolGetterFacet.getRemoveLiquidityFeeBps(address(bnb), 80000), 0);
  }
}
