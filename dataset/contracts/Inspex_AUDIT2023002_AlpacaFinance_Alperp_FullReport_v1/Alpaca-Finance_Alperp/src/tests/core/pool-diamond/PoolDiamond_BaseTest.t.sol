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

import { BaseTest, MockWNative, console, stdError, MockStrategy, MockDonateVault, ALP, MockFlashLoanBorrower, LibPoolConfigV1, PoolOracle, PoolRouter03, OwnershipFacetInterface, GetterFacetInterface, LiquidityFacetInterface, PerpTradeFacetInterface, AdminFacetInterface, FarmFacetInterface, AccessControlFacetInterface, LibAccessControl, FundingRateFacetInterface, Orderbook02, MarketOrderRouter, FastPriceFeed, PythPriceFeed, FakePyth } from "../../base/BaseTest.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

abstract contract PoolDiamond_BaseTest is BaseTest {
  PoolOracle internal poolOracle;
  address internal poolDiamond;
  PoolRouter03 internal poolRouter;
  ALP internal alp;

  MockWNative internal revenueToken;

  AdminFacetInterface internal poolAdminFacet;
  GetterFacetInterface internal poolGetterFacet;
  LiquidityFacetInterface internal poolLiquidityFacet;
  PerpTradeFacetInterface internal poolPerpTradeFacet;
  FarmFacetInterface internal poolFarmFacet;
  AccessControlFacetInterface internal poolAccessControlFacet;
  FundingRateFacetInterface internal poolFundingRateFacet;

  Orderbook02 internal orderbook;
  MarketOrderRouter internal marketOrderRouter;

  PythPriceFeed internal pythPriceFeed;
  IPyth internal pyth;

  function setUp() public virtual {
    revenueToken = deployMockWNative();

    BaseTest.PoolConfigConstructorParams memory poolConfigParams = BaseTest
      .PoolConfigConstructorParams({
        treasury: TREASURY,
        fundingInterval: 1 hours,
        mintBurnFeeBps: 30,
        taxBps: 50,
        stableBorrowingRateFactor: 100,
        borrowingRateFactor: 100,
        fundingRateFactor: 25,
        liquidationFeeUsd: 5 * 10**30
      });

    (poolOracle, poolDiamond) = deployPoolDiamond(poolConfigParams);

    (
      address[] memory tokens,
      PoolOracle.PriceFeedInfo[] memory priceFeedInfo
    ) = buildDefaultSetPriceFeedInput();
    poolOracle.setPriceFeed(tokens, priceFeedInfo);

    poolAdminFacet = AdminFacetInterface(poolDiamond);
    poolGetterFacet = GetterFacetInterface(poolDiamond);
    poolLiquidityFacet = LiquidityFacetInterface(poolDiamond);
    poolPerpTradeFacet = PerpTradeFacetInterface(poolDiamond);
    poolFarmFacet = FarmFacetInterface(poolDiamond);
    poolAccessControlFacet = AccessControlFacetInterface(poolDiamond);
    poolFundingRateFacet = FundingRateFacetInterface(poolDiamond);

    alp = poolGetterFacet.alp();

    // Pyth PriceFeed
    pyth = deployFakePyth(1, 0.01 ether); // no older than 1 sec for getPrice, 0.01 for fee
    pythPriceFeed = deployPythPriceFeed(address(pyth));

    poolRouter = deployPoolRouter(
      address(bnb),
      poolDiamond,
      address(pythPriceFeed)
    );
    poolAdminFacet.setRouter(address(poolRouter));

    alp.setWhitelist(address(poolRouter), true);
    // Grant Farm Keeper Role For This testing contract
    poolAccessControlFacet.grantRole(
      LibAccessControl.FARM_KEEPER,
      address(this)
    );

    // Grant Plugin for Orderbook (Limit Order) and MarketOrderRouter for (Market Order)
    orderbook = deployOrderbook(
      poolDiamond,
      address(poolOracle),
      address(bnb),
      0.01 ether,
      1 ether,
      address(pythPriceFeed)
    );
    poolAdminFacet.setPlugin(address(orderbook), true);
    marketOrderRouter = deployMarketOrderRouter(
      poolDiamond,
      address(poolOracle),
      address(bnb),
      1 ether,
      0.01 ether
    );
    poolAdminFacet.setPlugin(address(marketOrderRouter), true);

    // for majority of orderbook test cases, can omit pyth price first
    pythPriceFeed.setFavorRefPrice(true);
    pythPriceFeed.setUpdater(address(orderbook), true);
    pythPriceFeed.setUpdater(address(poolRouter), true);
    pythPriceFeed.setMaxPriceAge(15);
  }

  function zeroBytesArr() internal pure returns (bytes[] memory) {
    bytes[] memory data = new bytes[](1);
    return data;
  }

  function checkPoolBalanceWithState(address token, int256 offset) internal {
    uint256 balance = IERC20(token).balanceOf(address(poolDiamond));
    assertEq(
      balance,
      uint256(
        int256(poolGetterFacet.liquidityOf(token)) +
          int256(poolGetterFacet.feeReserveOf(token)) +
          offset
      )
    );
  }

  function getPriceBits(
    uint256 wbtcPrice,
    uint256 wethPrice,
    uint256 bnbPrice
  ) internal pure returns (uint256) {
    uint256 priceBits = 0;
    priceBits = priceBits | (wbtcPrice << (0 * 32));
    priceBits = priceBits | (wethPrice << (1 * 32));
    priceBits = priceBits | (bnbPrice << (2 * 32));
    return priceBits;
  }
}
