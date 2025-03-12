// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseTest, EsP88, MockWNative, WFeedableRewarder, FeedableRewarder, PLPStaking, console, stdError, MockStrategy, MockDonateVault, PLP, MockFlashLoanBorrower, LibPoolConfigV1, PoolOracle, PoolRouter, OwnershipFacetInterface, GetterFacetInterface, LiquidityFacetInterface, PerpTradeFacetInterface, AdminFacetInterface, FarmFacetInterface, AccessControlFacetInterface, LibAccessControl, FundingRateFacetInterface, Orderbook } from "../../base/BaseTest.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract PoolDiamond_BaseTest is BaseTest {
  PoolOracle internal poolOracle;
  address internal poolDiamond;
  PoolRouter internal poolRouter;
  PLP internal plp;

  EsP88 internal esP88;
  MockWNative internal revenueToken;

  WFeedableRewarder internal revenueRewarder;
  FeedableRewarder internal esP88Rewarder;

  PLPStaking internal plpStaking;
  AdminFacetInterface internal poolAdminFacet;
  GetterFacetInterface internal poolGetterFacet;
  LiquidityFacetInterface internal poolLiquidityFacet;
  PerpTradeFacetInterface internal poolPerpTradeFacet;
  FarmFacetInterface internal poolFarmFacet;
  AccessControlFacetInterface internal poolAccessControlFacet;
  FundingRateFacetInterface internal poolFundingRateFacet;

  Orderbook internal orderbook;

  function setUp() public virtual {
    esP88 = BaseTest.deployEsP88();
    esP88.setMinter(DAVE, true);

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

    plp = poolGetterFacet.plp();

    plpStaking = BaseTest.deployPLPStaking();

    //  setup for staking and rewarder
    revenueRewarder = BaseTest.deployWFeedableRewarder(
      "Protocol Revenue Rewarder",
      address(revenueToken),
      address(plpStaking)
    );
    esP88Rewarder = BaseTest.deployFeedableRewarder(
      "esP88 Rewarder",
      address(esP88),
      address(plpStaking)
    );

    address[] memory rewarders = new address[](2);
    rewarders[0] = address(revenueRewarder);
    rewarders[1] = address(esP88Rewarder);

    plpStaking.addStakingToken(address(plp), rewarders);

    poolRouter = deployPoolRouter(address(matic), address(plpStaking));
    poolAdminFacet.setRouter(address(poolRouter));

    plp.setWhitelist(address(plpStaking), true);
    plp.setWhitelist(address(poolRouter), true);
    // Grant Farm Keeper Role For This testing contract
    poolAccessControlFacet.grantRole(
      LibAccessControl.FARM_KEEPER,
      address(this)
    );

    orderbook = deployOrderbook(
      poolDiamond,
      address(poolOracle),
      address(matic),
      0.01 ether,
      1 ether
    );
    poolAdminFacet.setPlugin(address(orderbook), true);
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
}
