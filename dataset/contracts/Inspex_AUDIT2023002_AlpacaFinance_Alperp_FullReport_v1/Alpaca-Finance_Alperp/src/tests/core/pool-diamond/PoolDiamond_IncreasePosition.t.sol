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

import { PoolDiamond_BaseTest, console, LibPoolConfigV1, LiquidityFacetInterface, GetterFacetInterface, PerpTradeFacetInterface, FakePyth } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_IncreasePositionTest is PoolDiamond_BaseTest {
  bytes32 internal constant WBTC_PRICE_ID =
    0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
  bytes32 internal constant WBNB_PRICE_ID =
    0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f;
  bytes32 internal constant DAI_PRICE_ID =
    0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd;

  struct PriceFeedData {
    bytes32 id;
    int64 price;
    uint64 conf;
    int32 expo;
    int64 emaPrice;
    uint64 emaConf;
    uint64 publishTime;
  }

  function setUp() public override {
    super.setUp();

    (
      address[] memory tokens2,
      LibPoolConfigV1.TokenConfig[] memory tokenConfigs2
    ) = buildDefaultSetTokenConfigInput2();

    poolAdminFacet.setTokenConfigs(tokens2, tokenConfigs2);
  }

  function testRevert_WhenMsgSenderNotAllowed() external {
    vm.expectRevert(abi.encodeWithSignature("LibPoolV1_ForbiddenPlugin()"));
    poolPerpTradeFacet.increasePosition(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      0,
      true
    );
  }

  function testRevert_WhenLeverageDisabled() external {
    poolAdminFacet.setIsLeverageEnable(false);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_LeverageDisabled()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      true
    );
  }

  function testRevert_WhenLong_WhenMisMatchToken() external {
    vm.expectRevert(abi.encodeWithSignature("PerpTradeFacet_TokenMisMatch()"));
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(bnb),
      0,
      true
    );
  }

  function testRevert_WhenLong_WhenCollateralIsStable() external {
    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_CollateralTokenIsStable()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(dai),
      0,
      true
    );
  }

  function testRevert_WhenLong_WhenCollateralTokenNotAllow() external {
    vm.expectRevert(abi.encodeWithSignature("PerpTradeFacet_BadToken()"));
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(randomErc20),
      address(randomErc20),
      0,
      true
    );
  }

  function testRevert_WhenLong_WhenCollateralTooSmallForFee() external {
    wbtcPriceFeed.setLatestAnswer(50000 * 10**8);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_CollateralNotCoverFee()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      1000 * 10**30,
      true
    );
  }

  function testRevert_WhenLong_WhenPositionSizeInvalid() external {
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50000 * 10**8);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_BadPositionSize()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      true
    );
  }

  function testRevert_WhenLong_WhenLossesExceedCollateral() external {
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50000 * 10**8);

    wbtc.mint(address(poolDiamond), 2500);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_LossesExceedCollateral()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      1000 * 10**30,
      true
    );
  }

  function testRevert_WhenLong_WhenLiquidationFeeExceedCollateral() external {
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(address(poolDiamond), 12500);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_LiquidationFeeExceedCollateral()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      1000 * 10**30,
      true
    );
  }

  function testRevert_WhenLong_WhenMaxLeverageExceed() external {
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(address(poolDiamond), 22500);

    // Max leverage is 100x
    // We use 22500 sathoshi = 22500 / 1e8 * 40000 = 9 USD as a collateral
    // Long position size at 9 * 100 = 900 USD should be reverted as max leverage is exceeded
    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_MaxLeverageExceed()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      900 * 10**30,
      true
    );
  }

  function testRevert_WhenLong_WhenSizeSmallerThanCollateral() external {
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(address(poolDiamond), 22500);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_SizeSmallerThanCollateral()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      8 * 10**30,
      true
    );
  }

  function testRevert_WhenLong_WhenNotEnoughLiquidity() external {
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(address(poolDiamond), 22500);

    vm.expectRevert(
      abi.encodeWithSignature("LibPoolV1_InsufficientLiquidity()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      500 * 10**30,
      true
    );
  }

  function testRevert_WhenLong_WhenOpenInterestLongCeilingExceed() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(address(this), 3 * 10**8);
    wbtc.approve(address(poolRouter), 3 * 10**8);
    vm.startPrank(ALICE);
    alp.approve(address(poolRouter), type(uint256).max);
    vm.stopPrank();
    poolRouter.addLiquidity(address(wbtc), 3 * 10**8, ALICE, 0, zeroBytesArr());

    wbtc.mint(address(poolDiamond), 1 * 10**8);

    address[] memory tokens = new address[](1);
    tokens[0] = address(wbtc);
    LibPoolConfigV1.TokenConfig[]
      memory tokenConfigs = new LibPoolConfigV1.TokenConfig[](1);
    tokenConfigs[0] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: true,
      decimals: wbtc.decimals(),
      weight: 10000,
      minProfitBps: 75,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 9.97 * 10**8,
      openInterestLongCeiling: 1.5 * 10**8
    });
    poolAdminFacet.setTokenConfigs(tokens, tokenConfigs);

    vm.expectRevert(
      abi.encodeWithSignature("LibPoolV1_OverOpenInterestLongCeiling()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      80000 * 10**30,
      true
    );
  }

  function testCorrectness_WhenLong() external {
    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(ALICE, 1 * 10**8);

    // ----- Start Alice session -----
    vm.startPrank(ALICE);

    // Alice add liquidity with 117499 satoshi
    wbtc.approve(address(poolRouter), 117499);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 117499, ALICE, 0, zeroBytesArr());

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

    // Alice add liquidity again with 117499 satoshi
    wbtc.approve(address(poolRouter), 117499);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 117499, ALICE, 0, zeroBytesArr());

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
    assertEq(poolGetterFacet.alp().balanceOf(ALICE), 92573912195121951219);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 706);
    assertEq(poolGetterFacet.getAumE18(false), 93.7168 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 96.05972 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234292);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      93.7168 * 10**30
    );

    // Alice increase long position with sub account id = 0
    wbtc.approve(address(poolRouter), 22500);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      22500,
      0,
      address(wbtc),
      47 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // The following condition expected to be happened:
    // 1. Pool's WBTC liquidity should be:
    // = 234292 + 22500 - (((47 * 0.001) + (47 * 0)) / 41000)
    // = 234292 + 22500 - 114 = 256678 sathoshi
    // 2. Pool's WBTC reserved should be:
    // = 47 / 40000 = 117500 sathoshi
    // 3. Pool's WBTC guarantee USD should be:
    // = 47 + 0.0047 - ((22500 / 1e8) * 40000) = 38.047 USD
    // 4. Redeemable WBTC in USD should be:
    // = ((256678 + 92797 - 117500) / 1e8) * 40000 = 92.79 USD
    // 5. Pool's AUM by min price should be:
    // 38.047 + ((256678 - 117500) / 1e8) * 40000 = 93.7182 USD
    // 6. Pool's AUM by max price should be:
    // 38.047 + ((256678 - 117500) / 1e8) * 41000 = 95.10998 USD
    // 7. Pool should makes 706 + 114 = 820 sathoshi
    // 8. Pool's WBTC USD debt should still the same as before
    // 9. Pool's WBTC balance should be:
    // = 256678 + 820 = 257498 sathoshi
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 256678);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 117500);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 38.047 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      92.79 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 93.7182 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 95.10998 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 820);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 257498);
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      (47 * 10**30 * 10**8) / poolOracle.getMaxPrice(address(wbtc))
    );
    assertEq(poolGetterFacet.openInterestShort(address(wbtc)), 0);

    // Assert a postion
    // 1. Position's size should be 47 USD
    // 2. Position's collateral should be:
    // = ((22500 / 1e8) * 40000) - 0.047 = 8.953 USD
    // 3. Position's average price should be 41000 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 47 * 10**30);
    assertEq(position.collateral, 8.953 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 117500);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);

    vm.stopPrank();
    // ----- Stop Alice session ------
  }

  function testCorrectness_WhenLong_WhenNoFavorRefPrice() external {
    PriceFeedData memory wbtcPriceFeedDataStruct;
    bytes memory wbtcPriceFeedData;
    PriceFeedData memory wbnbPriceFeedDataStruct;
    bytes memory wbnbPriceFeedData;
    PriceFeedData memory daiPriceFeedDataStruct;
    bytes memory daiPriceFeedData;
    bytes[] memory data;
    {
      // Add block scope to Avoid stack-too-deep
      // Someone already update the BTC price, hence token price id can be set now
      // min price = 40k, max price = 41k, same as what primary oracle's latest answers
      wbtcPriceFeedDataStruct = PriceFeedData({
        id: WBTC_PRICE_ID,
        price: int64(4050000000000),
        conf: uint64(50000000000),
        expo: int32(-8),
        emaPrice: int64(4050000000000),
        emaConf: uint64(50000000000),
        publishTime: uint64(block.timestamp)
      });
      wbtcPriceFeedData = FakePyth(address(pyth)).createPriceFeedUpdateData({
        id: wbtcPriceFeedDataStruct.id,
        price: wbtcPriceFeedDataStruct.price,
        conf: wbtcPriceFeedDataStruct.conf,
        expo: wbtcPriceFeedDataStruct.expo,
        emaPrice: wbtcPriceFeedDataStruct.emaPrice,
        emaConf: wbtcPriceFeedDataStruct.emaConf,
        publishTime: wbtcPriceFeedDataStruct.publishTime
      });

      // Someone already update the BNB price, hence token price id can be set now
      // min price = 400, max price = 400, same as what primary oracle's latest answers
      wbnbPriceFeedDataStruct = PriceFeedData({
        id: WBTC_PRICE_ID,
        price: int64(40000000000),
        conf: uint64(0),
        expo: int32(-8),
        emaPrice: int64(40000000000),
        emaConf: uint64(0),
        publishTime: uint64(block.timestamp)
      });
      wbnbPriceFeedData = FakePyth(address(pyth)).createPriceFeedUpdateData({
        id: wbnbPriceFeedDataStruct.id,
        price: wbnbPriceFeedDataStruct.price,
        conf: wbnbPriceFeedDataStruct.conf,
        expo: wbnbPriceFeedDataStruct.expo,
        emaPrice: wbnbPriceFeedDataStruct.emaPrice,
        emaConf: wbnbPriceFeedDataStruct.emaConf,
        publishTime: wbnbPriceFeedDataStruct.publishTime
      });

      // Someone already update the DAI price, hence token price id can be set now
      // min price = 1, max price = 1, same as what primary oracle's latest answers
      daiPriceFeedDataStruct = PriceFeedData({
        id: WBTC_PRICE_ID,
        price: int64(100000000),
        conf: uint64(0),
        expo: int32(-8),
        emaPrice: int64(100000000),
        emaConf: uint64(0),
        publishTime: uint64(block.timestamp)
      });
      daiPriceFeedData = FakePyth(address(pyth)).createPriceFeedUpdateData({
        id: daiPriceFeedDataStruct.id,
        price: daiPriceFeedDataStruct.price,
        conf: daiPriceFeedDataStruct.conf,
        expo: daiPriceFeedDataStruct.expo,
        emaPrice: daiPriceFeedDataStruct.emaPrice,
        emaConf: daiPriceFeedDataStruct.emaConf,
        publishTime: daiPriceFeedDataStruct.publishTime
      });

      // update price in a Pyth contract
      data = new bytes[](3);
      data[0] = wbtcPriceFeedData;
      data[1] = wbnbPriceFeedData;
      data[2] = daiPriceFeedData;

      // 3 prices = 3 * 0.01 ether = 0.03 ether as a fee
      pyth.updatePriceFeeds{ value: 0.03 ether }(data);
      pythPriceFeed.setTokenPriceId(address(wbtc), WBTC_PRICE_ID);
      // set favor ref price to false so that we can integrate with pyth
      pythPriceFeed.setFavorRefPrice(false);
    }

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(ALICE, 1 * 10**8);

    // ----- Start Alice session -----
    vm.startPrank(ALICE);

    // Alice add liquidity with 117499 satoshi
    wbtc.approve(address(poolRouter), 117499);
    alp.approve(address(poolRouter), type(uint256).max);
    vm.deal(ALICE, ALICE.balance + 0.03 ether);
    poolRouter.addLiquidity{ value: 0.03 ether }(
      address(wbtc),
      117499,
      ALICE,
      0,
      data
    );

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

    // Alice add liquidity again with 117499 satoshi
    wbtc.approve(address(poolRouter), 117499);
    alp.approve(address(poolRouter), type(uint256).max);

    // Deal more BNB to ALICE to pay for update fee
    vm.deal(ALICE, ALICE.balance + 0.03 ether);
    poolRouter.addLiquidity{ value: 0.03 ether }(
      address(wbtc),
      117499,
      ALICE,
      0,
      data
    );

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
    assertEq(poolGetterFacet.alp().balanceOf(ALICE), 92573912195121951219);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 706);
    assertEq(poolGetterFacet.getAumE18(false), 93.7168 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 96.05972 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234292);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      93.7168 * 10**30
    );

    // Alice increase long position with sub account id = 0
    wbtc.approve(address(poolRouter), 22500);
    // Deal more BNB to ALICE to pay for update fee
    vm.deal(ALICE, ALICE.balance + 0.03 ether);
    poolRouter.increasePosition{ value: 0.03 ether }(
      0,
      address(wbtc),
      address(wbtc),
      22500,
      0,
      address(wbtc),
      47 * 10**30,
      true,
      type(uint256).max,
      data
    );

    // The following condition expected to be happened:
    // 1. Pool's WBTC liquidity should be:
    // = 234292 + 22500 - (((47 * 0.001) + (47 * 0)) / 41000)
    // = 234292 + 22500 - 114 = 256678 sathoshi
    // 2. Pool's WBTC reserved should be:
    // = 47 / 40000 = 117500 sathoshi
    // 3. Pool's WBTC guarantee USD should be:
    // = 47 + 0.0047 - ((22500 / 1e8) * 40000) = 38.047 USD
    // 4. Redeemable WBTC in USD should be:
    // = ((256678 + 92797 - 117500) / 1e8) * 40000 = 92.79 USD
    // 5. Pool's AUM by min price should be:
    // 38.047 + ((256678 - 117500) / 1e8) * 40000 = 93.7182 USD
    // 6. Pool's AUM by max price should be:
    // 38.047 + ((256678 - 117500) / 1e8) * 41000 = 95.10998 USD
    // 7. Pool should makes 706 + 114 = 820 sathoshi
    // 8. Pool's WBTC USD debt should still the same as before
    // 9. Pool's WBTC balance should be:
    // = 256678 + 820 = 257498 sathoshi
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 256678);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 117500);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 38.047 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      92.79 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 93.7182 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 95.10998 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 820);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 257498);
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      (47 * 10**30 * 10**8) / poolOracle.getMaxPrice(address(wbtc))
    );
    assertEq(poolGetterFacet.openInterestShort(address(wbtc)), 0);

    // Assert a postion
    // 1. Position's size should be 47 USD
    // 2. Position's collateral should be:
    // = ((22500 / 1e8) * 40000) - 0.047 = 8.953 USD
    // 3. Position's average price should be 41000 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 47 * 10**30);
    assertEq(position.collateral, 8.953 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 117500);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);

    vm.stopPrank();
    // ----- Stop Alice session ------
  }

  function testCorrectness_WhenLong_Native() external {
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    vm.deal(ALICE, 100 * 10**18);

    // ----- Start Alice session -----
    vm.startPrank(ALICE);

    // Alice add liquidity with 1 BNB
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidityNative{ value: 100 ether }(
      address(bnb),
      ALICE,
      0,
      zeroBytesArr()
    );

    vm.deal(ALICE, 1 * 10**18);
    poolRouter.increasePositionNative{ value: 1 ether }(
      0,
      address(bnb),
      address(bnb),
      0,
      address(bnb),
      30_000 * 1e30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(ALICE, 0, address(bnb), address(bnb), true);
    assertEq(position.size, 30_000 * 10**30);
    assertEq(position.collateral, 370 * 10**30);
    assertEq(position.averagePrice, 400 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 75 ether);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);
    assertEq(
      poolGetterFacet.openInterestLong(address(bnb)),
      (30_000 * 10**30 * 10**18) / poolOracle.getMaxPrice(address(bnb))
    );
    assertEq(poolGetterFacet.openInterestShort(address(bnb)), 0);
  }

  function testCorrectness_WhenLong_WithSwap() external {
    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(ALICE, 1 * 10**8);
    dai.mint(ALICE, 40000 ether);

    // ----- Start Alice session -----
    vm.startPrank(ALICE);

    // Alice add liquidity with 117499 satoshi
    wbtc.approve(address(poolRouter), 117499);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 117499, ALICE, 0, zeroBytesArr());

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

    // Alice add liquidity again with 117499 satoshi
    wbtc.approve(address(poolRouter), 117499);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 117499, ALICE, 0, zeroBytesArr());

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
    assertEq(poolGetterFacet.alp().balanceOf(ALICE), 92573912195121951219);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 706);
    assertEq(poolGetterFacet.getAumE18(false), 93.7168 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 96.05972 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234292);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      93.7168 * 10**30
    );

    // Alice increase long position with sub account id = 0
    dai.approve(address(poolRouter), type(uint256).max);
    poolRouter.increasePosition(
      0,
      address(dai),
      address(wbtc),
      9.225 ether,
      0,
      address(wbtc),
      47 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // The following condition expected to be happened:
    // 9.225 DAI was supplied to swap for WBTC at the price of 41000 USD/WBTC
    // 9.225 ether / 41000 = 22500 satoshi was the amount out
    // amount out after fee = 22500 * 0.997 = 22432
    // 1. Pool's WBTC liquidity should be:
    // = WBTC Initial Liquidity - Amount Out from Swap + Collateral from Increase Position - Margin Fee
    // = 234292 - 22500 + 22432 - (((47 * 0.001) + (47 * 0)) / 41000)
    // = 234292 - 22500 + 22432 - 114 = 234110 satoshi
    // 2. Pool's WBTC reserved should be:
    // = 47 / 40000 = 117500 sathoshi
    // 3. Pool's WBTC guarantee USD should be:
    // = 47 + 0.047 - ((22432 / 1e8) * 40000) = 38.0742 USD
    // 4. Redeemable WBTC in USD should be:
    // = ((234110 + 92863 - 117500) / 1e8) * 40000 = 83.7892 USD
    // 5. Pool's AUM by min price should be:
    // 38.0742 + ((234110 - 117500) / 1e8) * 40000 + 9.225 = 93.9432 USD
    // 6. Pool's AUM by max price should be:
    // 38.0742 + ((234110 - 117500) / 1e8) * 41000 + 9.225 = 95.1093 USD
    // 7. Pool should makes 706 + 68 + 114 = 888 sathoshi
    // 8. Pool's WBTC USD debt should still the same as before
    // 9. Pool's WBTC balance should be:
    // = 234110 + 888 = 234998 sathoshi
    // 10. WBTC USD Debt
    // = 93.7168 - 9.225 = 84.4918 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234110);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 117500);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 38.0742 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      83.7892 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 93.9432 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 95.1093 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 888);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 84.4918 * 10**18);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 234998);
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      (47 * 10**30 * 10**8) / poolOracle.getMaxPrice(address(wbtc))
    );
    assertEq(poolGetterFacet.openInterestShort(address(wbtc)), 0);

    // Assert a postion
    // 1. Position's size should be 47 USD
    // 2. Position's collateral should be:
    // = ((22432 / 1e8) * 40000) - 0.047 = 8.9258 USD
    // 3. Position's average price should be 41000 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 47 * 10**30);
    assertEq(position.collateral, 8.9258 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 117500);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);

    vm.stopPrank();
    // ----- Stop Alice session ------
  }

  function testCorretness_WhenLong_WhenPriceChanges_WhenIncreasePosition()
    external
  {
    daiPriceFeed.setLatestAnswer(1 * 10**18);
    bnbPriceFeed.setLatestAnswer(300 * 10**18);

    wbtcPriceFeed.setLatestAnswer(100_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(100_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(100_000 * 10**8);

    // Add 1 WBTC as a liquidity for the pool
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 0, address(this), 0, zeroBytesArr());

    // The following criteria should be met:
    // 1. address(this) should get 1 * (1-0.003) * 100000 = 99700 ALP
    // 2. Pool's WBTC liquidity should be:
    // = 1 * (1-0.003) = 0.997 WBTC
    // 3. Pool should make 0.003 WBTC as fee reserve
    // 4. Pool's WBTC USD debt should be:
    // = 1 * (1-0.003) * 100000 = 99700 USD
    // 5. Pool's AUM with min price should be:
    // = 0.997 * 100000 = 99700 USD
    // 6. Pool's AUM with max price should be:
    // = 0.997 * 100000 = 99700 USD
    assertEq(poolGetterFacet.alp().balanceOf(address(this)), 99700 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.997 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 0.003 * 10**8);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 99700 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 99700 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99700 * 10**18);

    // Long 80,000 USD on WBTC with 0.5 WBTC (50,000 USD) as a collateral
    // This is 80,000 / 50,000 = 1.6x
    wbtc.mint(address(poolDiamond), 0.5 * 10**8);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      80_000 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // The following conditions need to be met after long position created:
    // 1. Pool's liquidity should be:
    // = 0.997 + 0.5 - (((80000 * 0.001) + (0.5 * 0)) / 100000)
    // = 0.997 + 0.5 - 0.0008 = 1.4962 WBTC
    // 2. Pool's WBTC reserved should be:
    // = 80000 / 100000 = 0.8 WBTC
    // 3. Pool's WBTC guarantee USD should be:
    // = 80000 + 80 - (0.5 * 100000) = 30080 USD
    // 4. Redemptable WBTC in USD should be:
    // = 30080 + ((1.4962 - 0.8) * 100000) = 99700 USD
    // 5. Pool's AUM by min price should be:
    // = 30080 + ((1.4962 - 0.8) * 100000) = 99700 USD
    // 6. Pool's AUM by max price should be:
    // = 30080 + ((1.4962 - 0.8) * 100000) = 99700 USD
    // 7. Pool should makes 0.003 + 0.0008 = 0.0038 WBTC as fee reserve
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 1.4962 * 10**8);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.8 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 30080 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      99700 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 99700 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99700 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 0.0038 * 10**8);
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      (80_000 * 10**30 * 10**8) / poolOracle.getMaxPrice(address(wbtc))
    );
    assertEq(poolGetterFacet.openInterestShort(address(wbtc)), 0);

    // Assert position
    // 1. Position's size should be 80 USD
    // 2. Position's collateral should be:
    // = (0.5 - 0.0008) * 100000 = 49920 USD
    // 3. Position's average price should be 100000 USD
    // 4. Position's entry funding rate should be 0
    // 5. Position's reserve amount should be 0.8 WBTC
    // 6. Position's realized pnl should be 0
    // 7. Position's has profit should be true
    // 8. Position's last increased time should be block.timestamp
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 80_000 * 10**30);
    assertEq(position.collateral, 49920 * 10**30);
    assertEq(position.averagePrice, 100000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0.8 * 10**8);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);

    // WBTC price pump to 150,000 USD
    wbtcPriceFeed.setLatestAnswer(150_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(150_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(150_000 * 10**8);

    // The following conditions should be met:
    // 1. The position should be profitable
    // 2. The position's delta should be 0.8 * 150000 - 80000 = 40000 USD
    // 3. Pool's AUM by min price should be:
    // = 30080 + ((1.4962 - 0.8) * 150000) = 134510 USD
    // 4. Pool's AUM by max price should be:
    // = 30080 + ((1.4962 - 0.8) * 150000) = 134510 USD
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(isProfit);
    assertEq(delta, 40000 * 10**30);
    assertEq(poolGetterFacet.getAumE18(false), 134510 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 134510 * 10**18);

    // WBTC dump to 50,000 - 75,000 USD
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(75_000 * 10**8);

    // The following conditions should be met:
    // 1. The position should be in loss
    // 2. The position's delta should be 0.8 * 50000 - 80000 = -40000 USD
    // 3. Pool's AUM by min price should be:
    // = 30080 + ((1.4962 - 0.8) * 50000) = 64890 USD
    // 4. Pool's AUM by max price should be:
    // = 30080 + ((1.4962 - 0.8) * 75000) = 82295 USD
    assertTrue(isProfit);
    assertEq(delta, 40000 * 10**30);
    assertEq(poolGetterFacet.getAumE18(false), 64890 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 82295 * 10**18);
  }

  function testCorrectness_WhenLong_WhenAddCollateral() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);

    // Initiate first set of WBTC prices
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 117499 sathoshi as liquidity
    wbtc.mint(address(poolDiamond), 117499);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 0, address(this), 0, zeroBytesArr());

    // Assert pool's state.
    // 1. Pool's WBTC liquidity:
    // = 117499 * (1-0.003)
    // = 117146 sathoshi
    // 2. Pool should make:
    // = 353 sathoshi
    // 3. Pool's WBTC USD debt should be:
    // = 46.8584 USD
    // 4. Redemable WBTC in USD should be:
    // = 117146 * 40000 / 1e8
    // = 46.8584 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 117146);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 353);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 46.8584 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      46.8584 * 10**30
    );

    // Add 117499 sathoshi as liquidity
    wbtc.mint(address(poolDiamond), 117499);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 0, address(this), 0, zeroBytesArr());

    // Assert pool's state.
    // 1. Pool's WBTC liquidity:
    // = 117146 + 117499 * (1-0.003)
    // = 234292 sathoshi
    // 2. Pool should make:
    // = 353 + 353
    // = 706 sathoshi
    // 3. Pool's WBTC USD debt should be:
    // = 46.8584 + (117146 * 40000 / 1e8)
    // = 93.7168 USD
    // 4. Redemable WBTC in USD should be:
    // = 46.8584 + (117146 * 40000 / 1e8)
    // = 93.7168 USD
    // 5. Pool's AUM by min price should be:
    // = 234292 * 40000 / 1e8
    // = 93.7168 USD
    // 6. Pool's AUM by max price should be:
    // = 234292 * 41000 / 1e8
    // = 96.05972 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234292);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 706);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      93.7168 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 93.7168 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 96.05972 * 10**18);

    // Open a 47 USD WBTC long position with 22500 sathoshi as collateral
    wbtc.mint(address(poolDiamond), 22500);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      47 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // Assert pool's state:
    // 1. Pool's WBTC liquidity should be:
    // = 234292 + 22500 - (47 * 0.001 / 41000 * 1e8)
    // = 234292 + 22500 - 114
    // = 256678 sathoshi
    // 2. Pool should make:
    // = 706 + 114
    // = 820 sathoshi
    // 3. Pool's reserve amount should be:
    // = 47 / 40000 * 1e8
    // = 117500 sathoshi
    // 4. Pool's guaranteed USD should be:
    // = 47 + (47 * 0.001) - (22500 * 40000 / 1e8)
    // = 38.047 USD
    // 5. Redempable WBTC should be:
    // = ((38.047 / 41000 * 1e8) + 256678 - 117500) * 40000 / 1e8
    // = 92.79 USD
    // 6. Pool's AUM by min price should be:
    // = 38.047 + ((256678 - 117500) * 40000 / 1e8)
    // = 93.7182 USD
    // 7. Pool's AUM by max price should be:
    // = 38.047 + ((256678 - 117500) * 41000 / 1e8)
    // = 95.10998 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 256678);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 820);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 117500);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 38.047 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      92.79 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 93.7182 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 95.10998 * 10**18);
    uint256 openInterestLong = (47 * 10**30 * 10**8) /
      poolOracle.getMaxPrice(address(wbtc));
    assertEq(poolGetterFacet.openInterestLong(address(wbtc)), openInterestLong);
    assertEq(poolGetterFacet.openInterestShort(address(wbtc)), 0);

    // Assert position
    // 1. Position's size should be 47 USD.
    // 2. Position's collateral should be:
    // = (22500 * 40000 / 1e8) - (47 * 0.001)
    // = 8.953 USD
    // 3. Position's average price should be 41000 USD
    // 4. Position's entry funding rate should be 0
    // 5. Reserve amount should be:
    // = 47 / 40000 * 1e8
    // = 117500 sathoshi
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 47 * 10**30);
    assertEq(position.collateral, 8.953 * 10**30);
    assertEq(position.averagePrice, 41_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 117500);

    // Assert position's leverage
    // 1. Position leverage should be ~5.2x
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      52496
    );

    // Add 22500 sats as a collateral
    wbtc.mint(address(poolDiamond), 22500);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      0,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // Assert pool's state:
    // 1. Pool's WBTC liquidity should be:
    // = 256678 + 22500
    // = 279178 sathoshi
    // 2. Pool's WBTC should be the same: 820 sathoshi
    // 3. Pool's reserve amount should be remained the same
    // = 117500 sathoshi
    // 4. Pool's guaranteed USD should be:
    // = 38.047 - (22500 * 40000 / 1e8)
    // = 29.047 USD
    // 5. Redempable WBTC should be:
    // = ((29.047 / 41000 * 1e8) + 279178 - 117500) * 40000 / 1e8
    // = (70846 + 279178 - 117500) * 40000 / 1e8
    // = 93.0096 USD
    // 6. Pool's AUM by min price should be:
    // = 29.047 + ((279178 - 117500) * 40000 / 1e8)
    // = 93.7182 USD
    // 7. Pool's AUM by max price should be:
    // = 29.047 + ((279178 - 117500) * 41000 / 1e8)
    // = 95.33498 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 279178);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 820);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 117500);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 29.047 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      93.0096 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 93.7182 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 95.33498 * 10**18);
    assertEq(poolGetterFacet.openInterestLong(address(wbtc)), openInterestLong);
    assertEq(poolGetterFacet.openInterestShort(address(wbtc)), 0);

    // Assert position
    // 1. Position's size should be 47 USD.
    // 2. Position's collateral should be:
    // = 8.953 + (22500 * 40000 / 1e8)
    // = 8.953 + 9
    // = 17.953 USD
    // 3. Position's average price should be 41000 USD
    // 4. Position's entry funding rate should be 0
    // 5. Reserve amount should be:
    // = 47 / 40000 * 1e8
    // = 117500 sathoshi
    position = poolGetterFacet.getPosition(
      address(this),
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 47 * 10**30);
    assertEq(position.collateral, 17.953 * 10**30);
    assertEq(position.averagePrice, 41_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 117500);

    // Assert position's leverage
    // 1. Position leverage should be ~2.6x
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      26179
    );

    // Feed WBTC prices
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(51_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);

    // Assert pool state:
    // 1. Pool's AUM by min price should be:
    // = 29.047 + ((279178 - 117500) * 50000 / 1e8)
    // = 109.886 USD
    // 2. Pool's AUM by max price should be:
    // = 29.047 + ((279178 - 117500) * 51000 / 1e8)
    // = 111.50278 USD
    assertEq(poolGetterFacet.getAumE18(false), 109.886 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 111.50278 * 10**18);

    // Add another 100 sats as collateral
    wbtc.mint(address(poolDiamond), 100);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      0,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // Assert position
    // 1. Position's size should be 47 USD.
    // 2. Position's collateral should be:
    // = 17.953 + (100 * 50000 / 1e8)
    // = 18.003 USD
    // 3. Position's average price should be 41000 USD
    // 4. Position's entry funding rate should be 0
    // 5. Reserve amount should be:
    // = 47 / 40000 * 1e8
    // = 117500 sathoshi
    position = poolGetterFacet.getPosition(
      address(this),
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 47 * 10**30);
    assertEq(position.collateral, 18.003 * 10**30);
    assertEq(position.averagePrice, 41_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 117500);
    assertEq(poolGetterFacet.openInterestLong(address(wbtc)), openInterestLong);
    assertEq(poolGetterFacet.openInterestShort(address(wbtc)), 0);

    // Assert position's leverage
    // 1. Position leverage should be ~2.6x
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      26106
    );

    checkPoolBalanceWithState(address(wbtc), 0);
  }

  function testRevert_WhenShort_WhenCollateralNotStable() external {
    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_CollateralTokenNotStable()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      1,
      false
    );
  }

  function testRevert_WhenShort_WhenIndexTokenIsStable() external {
    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_IndexTokenIsStable()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(dai),
      1,
      false
    );
  }

  function testRevert_WhenShort_WhenIndexTokenNotShortable() external {
    address[] memory tokens = new address[](1);
    tokens[0] = address(bnb);

    LibPoolConfigV1.TokenConfig[]
      memory tokenConfigs = new LibPoolConfigV1.TokenConfig[](1);
    tokenConfigs[0] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: false,
      decimals: bnb.decimals(),
      weight: 10000,
      minProfitBps: 75,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });
    poolAdminFacet.setTokenConfigs(tokens, tokenConfigs);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_IndexTokenNotShortable()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(bnb),
      1,
      false
    );
  }

  function testRevert_WhenShort_WhenCollateralTooSmallForFee() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50000 * 10**8);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_CollateralNotCoverFee()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      1000 * 10**30,
      false
    );
  }

  function testRevert_WhenShort_WhenPositionSizeInvalid() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50000 * 10**8);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_BadPositionSize()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      false
    );
  }

  function testRevert_WhenShort_WhenLossesExceedCollateral() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);

    dai.mint(address(poolDiamond), 4 * 10**18);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_LossesExceedCollateral()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      1000 * 10**30,
      false
    );
  }

  function testRevert_WhenShort_WhenLiquidationFeeExceedCollateral() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    dai.mint(address(poolDiamond), 4.9 * 10**18);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_LiquidationFeeExceedCollateral()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      100 * 10**30,
      false
    );
  }

  function testRevert_WhenShort_WhenMaxLeverageExceed() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    dai.mint(address(poolDiamond), 10.9 * 10**18);

    // Max leverage is 88x
    // We use 10.9 DAI = 10.9 USD as a collateral
    // Short position size at 10.9 * 100 = 1090 USD should be reverted as max leverage is exceeded
    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_MaxLeverageExceed()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      1090 * 10**30,
      false
    );
  }

  function testRevert_WhenShort_WhenSizeSmallerThanCollateral() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    dai.mint(address(poolDiamond), 10.9 * 10**18);

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_SizeSmallerThanCollateral()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      8 * 10**30,
      false
    );
  }

  function testRevert_WhenShort_WhenNotEnoughLiquidity() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    dai.mint(address(poolDiamond), 10.9 * 10**18);

    vm.expectRevert(
      abi.encodeWithSignature("LibPoolV1_InsufficientLiquidity()")
    );
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      100 * 10**30,
      false
    );
  }

  function testCorrectness_WhenShort() external {
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

    // --- Start Alice session --- //
    vm.startPrank(ALICE);

    // Alice performs add liquidity by a 500 DAI
    dai.approve(address(poolRouter), 500 * 10**18);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(
      address(dai),
      500 * 10**18,
      ALICE,
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 500 * (1-0.0004) = 499.8 DAI
    // 2. Pool should make 0.2 DAI in fee
    // 3. Pool's DAI usd debt should be 499.8 USD
    // 4. Redemptable DAI collateral should be 499.8 USD
    // 5. Pool's AUM by min price should be 499.8 USD
    // 6. Pool's AUM by max price should be 499.8 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.2 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      499.8 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 499.8 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 499.8 * 10**18);

    vm.stopPrank();
    // ---- Stop Alice session ---- //

    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // ---- Start Alice session ---- //
    vm.startPrank(ALICE);

    // Alice opens a 90 USD WBTC short position with 20 DAI as a collateral
    dai.approve(address(poolRouter), 20 * 10**18);
    poolRouter.increasePosition(
      0,
      address(dai),
      address(dai),
      20 * 10**18,
      0,
      address(wbtc),
      90 * 10**30,
      false,
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be the same.
    // 2. Pool's DAI USD debt should be the same.
    // 2. Pool's DAI reserved should be 90 DAI
    // 3. Pool's guaranteed USD should be 0
    // 4. Redemptable DAI collateral should be 499.8 USD (same as liquidity)
    // 5. Pool should makes 0.2 + ((90 * 0.001)) = 0.29 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      499.8 * 10**30
    );
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.29 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.openInterestLong(address(wbtc)), 0);
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      (90 * 10**30 * 10**8) / poolOracle.getMaxPrice(address(wbtc))
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
    assertEq(position.entryBorrowingRate, 0);
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

  function testCorrectness_WhenShort_WithSwap() external {
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

    // --- Start Alice session --- //
    vm.startPrank(ALICE);

    // Alice performs add liquidity by a 500 DAI
    dai.approve(address(poolRouter), 500 * 10**18);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(
      address(dai),
      500 * 10**18,
      ALICE,
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 500 * (1-0.0004) = 499.8 DAI
    // 2. Pool should make 0.2 DAI in fee
    // 3. Pool's DAI usd debt should be 499.8 USD
    // 4. Redemptable DAI collateral should be 499.8 USD
    // 5. Pool's AUM by min price should be 499.8 USD
    // 6. Pool's AUM by max price should be 499.8 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.2 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      499.8 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 499.8 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 499.8 * 10**18);

    vm.stopPrank();
    // ---- Stop Alice session ---- //

    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // ---- Start Alice session ---- //
    wbtc.mint(ALICE, 1 * 10**8);
    vm.startPrank(ALICE);

    // Alice opens a 90 USD WBTC short position with 0.005 WBTC swapped to ~20 DAI as a collateral
    wbtc.approve(address(poolRouter), type(uint256).max);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(dai),
      0.0005 * 10**8,
      0,
      address(wbtc),
      90 * 10**30,
      false,
      0,
      zeroBytesArr()
    );
    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be reduced by 20 DAI from the swap
    // = 499.8 - 20 = 479.8 DAI
    // 2. Pool's DAI USD debt should be reduced by 20 DAI from the swap
    // = 499.8 - 20 = 479.8 DAI
    // 2. Pool's DAI reserved should be 90 DAI
    // 3. Pool's guaranteed USD should be 0
    // 4. Redemptable DAI collateral should be reduced by 20 DAI from the swap
    // = 499.8 - 20 = 479.8 DAI
    // 5. Pool should makes 0.2 + ((90 * 0.001)) + (20 * 0.003) = 0.35 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 479.8 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 479.8 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      479.8 * 10**30
    );
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.35 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.openInterestLong(address(wbtc)), 0);
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      (90 * 10**30 * 10**8) / poolOracle.getMaxPrice(address(wbtc))
    );
  }

  function testCorrectness_WhenShort_WithSwap_NativeIn() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(1 * 10**8);

    // Set mintBurnFeeBps to 4 BPS
    poolAdminFacet.setMintBurnFeeBps(4);

    // Feed WBTC price to be 40,000 USD
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Mint 1,000 DAI to Alice
    dai.mint(ALICE, 1000 * 10**18);

    // --- Start Alice session --- //
    vm.startPrank(ALICE);

    // Alice performs add liquidity by a 500 DAI
    dai.approve(address(poolRouter), 500 * 10**18);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(
      address(dai),
      500 * 10**18,
      ALICE,
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 500 * (1-0.0004) = 499.8 DAI
    // 2. Pool should make 0.2 DAI in fee
    // 3. Pool's DAI usd debt should be 499.8 USD
    // 4. Redemptable DAI collateral should be 499.8 USD
    // 5. Pool's AUM by min price should be 499.8 USD
    // 6. Pool's AUM by max price should be 499.8 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.2 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      499.8 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 499.8 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 499.8 * 10**18);

    vm.stopPrank();
    // ---- Stop Alice session ---- //

    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // ---- Start Alice session ---- //
    vm.deal(ALICE, 20 * 10**18);
    vm.startPrank(ALICE);

    // Alice opens a 90 USD WBTC short position with 20 BNB swapped to ~20 DAI as a collateral
    poolRouter.increasePositionNative{ value: 20 * 10**18 }(
      0,
      address(bnb),
      address(dai),
      0,
      address(wbtc),
      90 * 10**30,
      false,
      0,
      zeroBytesArr()
    );
    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be reduced by 20 DAI from the swap
    // = 499.8 - 20 = 479.8 DAI
    // 2. Pool's DAI USD debt should be reduced by 20 DAI from the swap
    // = 499.8 - 20 = 479.8 DAI
    // 2. Pool's DAI reserved should be 90 DAI
    // 3. Pool's guaranteed USD should be 0
    // 4. Redemptable DAI collateral should be reduced by 20 DAI from the swap
    // = 499.8 - 20 = 479.8 DAI
    // 5. Pool should makes 0.2 + ((90 * 0.001)) + (20 * 0.003) = 0.35 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 479.8 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 479.8 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      479.8 * 10**30
    );
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.35 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.openInterestLong(address(wbtc)), 0);
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      (90 * 10**30 * (10**8)) / poolOracle.getMaxPrice(address(wbtc))
    );

    // Assert a position:
    // 1. Position's size should be 90
    // 2. Position's collateral should be (20 * 0.997) - (90 * 0.001) = 19.85 DAI
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
    assertEq(position.collateral, 19.85 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
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

  function testCorrectness_WhenShort_MinProfitBps() external {
    poolAdminFacet.setMintBurnFeeBps(4);
    poolAdminFacet.setMinProfitDuration(8 hours);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    // Add 100 as a liquidity
    dai.mint(address(poolDiamond), 100 * 10**18);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(dai), 0, address(this), 0, zeroBytesArr());

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Open a 90 USD WBTC short position with 10 DAI as a collateral
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolRouter.increasePosition(
      0,
      address(dai),
      address(dai),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      false,
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // = 100 * (1-0.0004) + (90 * (40000-40000) / 40000)
    // = 99.96 USD
    // 2. Pool's AUM by max price should be:
    // = 100 * (1-0.0004) + (90 * (41000-40000) / 40000)
    // = 102.21 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.21 * 10**18);
    assertEq(poolGetterFacet.openInterestLong(address(wbtc)), 0);
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      (90 * 10**30 * 10**8) / poolOracle.getMaxPrice(address(wbtc))
    );

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be 10 * (1-0.001) = 9.91
    // 3. Position's average price should be 40,000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount: 90
    // 6. Position's realized PnL should be: 0
    // 7. Position's has realized profit should be true
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
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0 * 10**30);
    assertTrue(position.hasProfit);

    // Oracle fed WBTC to be at 40,000 * (100 - 0.75)% = 39700
    wbtcPriceFeed.setLatestAnswer(39_700 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_700 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_700 * 10**8);

    // Assert position delta
    // Profit not pass minBps so delta is 0
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertTrue(isProfit);
    assertEq(delta, 0);

    // increase time 1 hour (not pass minProfitDuration)
    vm.warp(block.timestamp + 1 hours);

    // Assert position delta again after time passed.
    // Profit pass minBps so delta is 0
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertTrue(isProfit);
    assertEq(delta, 0);

    // increase time 7 hours and 1 second (pass minProfitDuration)
    vm.warp(block.timestamp + 7 hours + 1 seconds);

    // Assert position delta again after time passed.
    // Time passed minProfitDuration, so delta needs to calculate.
    // Position's delta should be:
    // = 90 * (40000 - 39700) / 40000
    // = 0.675 USD
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertTrue(isProfit);
    assertEq(delta, 0.675 * 10**30);
  }
}
