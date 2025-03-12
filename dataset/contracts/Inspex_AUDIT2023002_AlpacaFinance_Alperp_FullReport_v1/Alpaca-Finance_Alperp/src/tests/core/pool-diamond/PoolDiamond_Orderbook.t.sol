// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, console, LibPoolConfigV1, LiquidityFacetInterface, GetterFacetInterface, PerpTradeFacetInterface, PythPriceFeed, FakePyth } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_Orderbook is PoolDiamond_BaseTest {
  bytes32 internal constant WBTC_PRICE_ID =
    0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;

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
    orderbook.setWhitelist(address(this), true);

    address[] memory _signers = new address[](1);
    _signers[0] = address(this);
    address[] memory _updaters = new address[](1);
    _updaters[0] = address(this);

    address[] memory _tokens = new address[](3);
    _tokens[0] = address(wbtc);
    _tokens[1] = address(weth);
    _tokens[2] = address(bnb);
    uint256[] memory _tokenPrecisions = new uint256[](3);
    _tokenPrecisions[0] = 1000;
    _tokenPrecisions[1] = 1000;
    _tokenPrecisions[2] = 1000;
    uint256[] memory _maxCumulativeDeltaDiffs = new uint256[](3);
    _maxCumulativeDeltaDiffs[0] = 1000000;
    _maxCumulativeDeltaDiffs[1] = 1000000;
    _maxCumulativeDeltaDiffs[2] = 1000000;

    poolOracle.setSecondaryPriceFeed(address(pythPriceFeed));
    poolOracle.setIsSecondaryPriceEnabled(true);

    orderbook.setWhitelist(address(this), true);
  }

  function testRevert_IncreaseOrder_InsufficientExecutionFee() external {
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InsufficientExecutionFee()"));
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0 ether,
      _shouldWrap: false
    });
  }

  function testRevert_IncreaseOrder_OnlyNativeShouldWrap() external {
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("OnlyNativeShouldWrap()"));
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0.01 ether,
      _shouldWrap: true
    });
  }

  function testRevert_IncreaseOrder_IncorrectValueTransfer() external {
    address[] memory path = new address[](1);
    path[0] = address(bnb);
    vm.expectRevert(abi.encodeWithSignature("IncorrectValueTransfer()"));
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0.01 ether,
      _shouldWrap: true
    });
  }

  function testRevert_IncreaseOrder_InvalidPath() external {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(wbtc);
    wbtc.approve(address(orderbook), 22500);
    wbtc.mint(address(this), 22500);
    vm.expectRevert(abi.encodeWithSignature("InvalidPath()"));
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0.01 ether,
      _shouldWrap: false
    });
  }

  function testRevert_DecreaseOrder_InsufficientExecutionFee() external {
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InsufficientExecutionFee()"));
    orderbook.createDecreaseOrder{ value: 0.001 ether }({
      _subAccountId: 0,
      _indexToken: address(wbtc),
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _collateralDelta: 0,
      _isLong: true,
      _triggerPrice: 44_000 * 10**30,
      _triggerAboveThreshold: true
    });
  }

  function testCorrectness_WhenLong_WhenFavorRefPrice() external {
    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(ALICE, 1 * 10**8);

    // ----- Start Alice session -----
    vm.deal(ALICE, 100 ether);
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
    assertEq(poolGetterFacet.alp().balanceOf(address(ALICE)), 46.8584 * 10**18);
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
    poolRouter.addLiquidity(address(wbtc), 117499, ALICE, 0, zeroBytesArr());

    // After Alice added 117499 satoshi as a liquidity,
    // the following conditions should be met:
    // 1. Alice Contract should get 46.8584 + (46.8584 * 46.8584 / 48.02986) = 92573912195121951219 ALP
    // 2. Pool should make 706 sathoshi
    // 3. Pool's AUM by min price should be:
    // 46.8584 + (0.00117499 * (1-0.003) * 40000) = 93.7168 USD
    // 4. Pool's AUM by max price should be:
    // 48.02986 + (0.00117499 * (1-0.003) * 41000) = 96.05972 USD
    // 5. WBTC's USD debt should be 93.7168 USD
    // 6. WBTC's liquidity should be 117146 + 117499 - 353 = 234292 satoshi
    // 7. Redeemable WBTC in USD should be 93.7168 USD
    assertEq(
      poolGetterFacet.alp().balanceOf(address(ALICE)),
      92573912195121951219
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

    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);

    // Alice increase long position with sub account id = 0
    vm.startPrank(ALICE);
    wbtc.approve(address(orderbook), 22500);
    poolAccessControlFacet.allowPlugin(address(orderbook));
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0.01 ether,
      _shouldWrap: false
    });

    // Cancel the submitted order and create the same one again
    orderbook.cancelIncreaseOrder(0, 0);
    assertEq(ALICE.balance, 100 ether);

    wbtc.approve(address(orderbook), 22500);
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0.01 ether,
      _shouldWrap: false
    });

    (
      address purchaseToken,
      uint256 purchaseTokenAmount,
      address collateralToken,
      address indexToken,
      uint256 sizeDelta,
      bool isLong,
      uint256 triggerPrice,
      bool triggerAboveThreshold
    ) = orderbook.getIncreaseOrder(ALICE, 0, 1);
    assertEq(purchaseToken, address(wbtc));
    assertEq(purchaseTokenAmount, 22500);
    assertEq(collateralToken, address(wbtc));
    assertEq(indexToken, address(wbtc));
    assertEq(sizeDelta, 47 * 10**30);
    assertTrue(isLong);
    assertEq(triggerPrice, 41_001 * 10**30);
    assertFalse(triggerAboveThreshold);
    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Execute Alice's order
    (bool shouldExecute, uint160[] memory orderList) = orderbook
      .getShouldExecuteOrderList(false, 10);
    assertTrue(shouldExecute);
    vm.warp(1669832202); // warp ahead

    // executeOrders(orderList, payable(BOB));
    bytes[] memory data = new bytes[](1);
    orderbook.executeIncreaseOrder(ALICE, 0, 1, payable(BOB), data);
    // Bob should receive 0.01 ether as execution fee
    assertEq(BOB.balance, 0.01 ether);

    // The following condition expected to be happened:
    // 1. Pool's WBTC liquidity should be:
    // = 234292 + 22500 - (((47 * 0.001) + (47 * 0)) / 41000)
    // = 234292 + 22500 - 114 = 256678 sathoshi
    // 2. Pool's WBTC reserved should be:
    // = 47 / 41000 = 114634 sathoshi
    // 3. Pool's WBTC guarantee USD should be:
    // = 47 + 0.047 - ((22500 / 1e8) * 41000) = 37.822 USD
    // 4. Redeemable WBTC in USD should be:
    // = ((256678 + 92248 - 114634) / 1e8) * 41000 = 96.05972 USD
    // 5. Pool's AUM by min price should be:
    // 37.822 + ((256678 - 114634) / 1e8) * 41000 = 96.06004 USD
    // 6. Pool's AUM by max price should be:
    // 37.822 + ((256678 - 114634) / 1e8) * 41000 = 96.06004 USD
    // 7. Pool should makes 706 + 114 = 820 sathoshi
    // 8. Pool's WBTC USD debt should still the same as before
    // 9. Pool's WBTC balance should be:
    // = 256678 + 820 = 257498 sathoshi
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 256678);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 114634);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 37.822 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      96.05972 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 96.06004 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 96.06004 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 820);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 257498);

    // Assert a postion
    // 1. Position's size should be 47 USD
    // 2. Position's collateral should be:
    // = ((22500 / 1e8) * 41000) - 0.047 = 9.178 USD
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
    assertEq(position.collateral, 9.178 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 114634);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);

    vm.startPrank(ALICE);
    orderbook.createDecreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _indexToken: address(wbtc),
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _collateralDelta: position.collateral,
      _isLong: true,
      _triggerPrice: 44_000 * 10**30,
      _triggerAboveThreshold: true
    });
    vm.stopPrank();
    // ----- Stop Alice session ------

    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);

    uint256 aliceWBTCBalanceBefore = wbtc.balanceOf(ALICE);

    vm.warp(block.timestamp + 1000);

    // executeOrders(orderList, payable(BOB));
    orderbook.executeDecreaseOrder(ALICE, 0, 0, payable(BOB), data);
    // Bob should receive another 0.01 ether as execution fee
    assertEq(BOB.balance, 0.02 ether);

    position = poolGetterFacet.getPositionWithSubAccountId(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    // Position should be closed
    assertEq(position.collateral, 0, "Alice position should be closed");
    assertGt(
      wbtc.balanceOf(ALICE) - aliceWBTCBalanceBefore,
      22500,
      "Alice should receive collateral and profit."
    );
  }

  function testCorrectness_WhenLong_WhenNoFavorRefPrice() external {
    {
      // Add block scope to Avoid stack-too-deep
      // Someone already update the price, hence token price id can be set now
      // min price = 40k, max price = 41k, same as what primary oracle's latest answers
      PriceFeedData memory priceFeedDataStruct = PriceFeedData({
        id: WBTC_PRICE_ID,
        price: int64(4050000000000),
        conf: uint64(50000000000),
        expo: int32(-8),
        emaPrice: int64(4050000000000),
        emaConf: uint64(50000000000),
        publishTime: uint64(block.timestamp)
      });
      bytes memory priceFeedData = FakePyth(address(pyth))
        .createPriceFeedUpdateData({
          id: priceFeedDataStruct.id,
          price: priceFeedDataStruct.price,
          conf: priceFeedDataStruct.conf,
          expo: priceFeedDataStruct.expo,
          emaPrice: priceFeedDataStruct.emaPrice,
          emaConf: priceFeedDataStruct.emaConf,
          publishTime: priceFeedDataStruct.publishTime
        });

      // update price in a Pyth contract
      bytes[] memory data = new bytes[](1);
      data[0] = priceFeedData;
      pyth.updatePriceFeeds{ value: 0.01 ether }(data);
      pythPriceFeed.setTokenPriceId(address(wbtc), WBTC_PRICE_ID);
      // set favor ref price to false so that we can integrate with pyth
      pythPriceFeed.setFavorRefPrice(false);
    }

    // set min execution fee to 0.02
    // 0.02 on gas fee, the other 0.02 on update price fee
    orderbook.setMinExecutionFee(0.02 ether);

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(ALICE, 1 * 10**8);

    // ----- Start Alice session -----
    vm.deal(ALICE, 100.02 ether);
    vm.startPrank(ALICE);

    // Alice add liquidity with 117499 satoshi
    wbtc.approve(address(poolRouter), 117499);
    alp.approve(address(poolRouter), type(uint256).max);
    vm.stopPrank();

    // Add liquidity with update fee
    {
      // Add block scope to Avoid stack-too-deep
      PriceFeedData memory priceFeedDataStruct = PriceFeedData({
        id: WBTC_PRICE_ID,
        price: int64(4050000000000),
        conf: uint64(50000000000),
        expo: int32(-8),
        emaPrice: int64(4050000000000),
        emaConf: uint64(50000000000),
        publishTime: uint64(block.timestamp)
      });
      bytes memory priceFeedData = FakePyth(address(pyth))
        .createPriceFeedUpdateData({
          id: priceFeedDataStruct.id,
          price: priceFeedDataStruct.price,
          conf: priceFeedDataStruct.conf,
          expo: priceFeedDataStruct.expo,
          emaPrice: priceFeedDataStruct.emaPrice,
          emaConf: priceFeedDataStruct.emaConf,
          publishTime: priceFeedDataStruct.publishTime
        });

      // update price in a Pyth contract
      bytes[] memory data = new bytes[](1);
      data[0] = priceFeedData;

      vm.startPrank(ALICE);
      poolRouter.addLiquidity{ value: 0.01 ether }(
        address(wbtc),
        117499,
        ALICE,
        0,
        data
      );
      vm.stopPrank();
    }

    vm.startPrank(ALICE);
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
    assertEq(poolGetterFacet.alp().balanceOf(address(ALICE)), 46.8584 * 10**18);
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

    vm.stopPrank();

    // Add liquidity with update fee
    {
      // Add block scope to Avoid stack-too-deep
      PriceFeedData memory priceFeedDataStruct = PriceFeedData({
        id: WBTC_PRICE_ID,
        price: int64(4050000000000),
        conf: uint64(50000000000),
        expo: int32(-8),
        emaPrice: int64(4050000000000),
        emaConf: uint64(50000000000),
        publishTime: uint64(block.timestamp)
      });
      bytes memory priceFeedData = FakePyth(address(pyth))
        .createPriceFeedUpdateData({
          id: priceFeedDataStruct.id,
          price: priceFeedDataStruct.price,
          conf: priceFeedDataStruct.conf,
          expo: priceFeedDataStruct.expo,
          emaPrice: priceFeedDataStruct.emaPrice,
          emaConf: priceFeedDataStruct.emaConf,
          publishTime: priceFeedDataStruct.publishTime
        });

      // update price in a Pyth contract
      bytes[] memory data = new bytes[](1);
      data[0] = priceFeedData;

      vm.startPrank(ALICE);
      poolRouter.addLiquidity{ value: 0.01 ether }(
        address(wbtc),
        117499,
        ALICE,
        0,
        data
      );
      vm.stopPrank();
    }

    // After Alice added 117499 satoshi as a liquidity,
    // the following conditions should be met:
    // 1. Alice Contract should get 46.8584 + (46.8584 * 46.8584 / 48.02986) = 92573912195121951219 ALP
    // 2. Pool should make 706 sathoshi
    // 3. Pool's AUM by min price should be:
    // 46.8584 + (0.00117499 * (1-0.003) * 40000) = 93.7168 USD
    // 4. Pool's AUM by max price should be:
    // 48.02986 + (0.00117499 * (1-0.003) * 41000) = 96.05972 USD
    // 5. WBTC's USD debt should be 93.7168 USD
    // 6. WBTC's liquidity should be 117146 + 117499 - 353 = 234292 satoshi
    // 7. Redeemable WBTC in USD should be 93.7168 USD
    assertEq(
      poolGetterFacet.alp().balanceOf(address(ALICE)),
      92573912195121951219
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

    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);

    // Alice increase long position with sub account id = 0
    vm.startPrank(ALICE);
    wbtc.approve(address(orderbook), 22500);
    poolAccessControlFacet.allowPlugin(address(orderbook));
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    orderbook.createIncreaseOrder{ value: 0.02 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0.02 ether,
      _shouldWrap: false
    });

    // Cancel the submitted order and create the same one again
    orderbook.cancelIncreaseOrder(0, 0);
    assertEq(ALICE.balance, 100 ether);

    wbtc.approve(address(orderbook), 22500);
    // 0.01 ether from update fee, 0.01 from execution fee
    orderbook.createIncreaseOrder{ value: 0.02 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0.02 ether,
      _shouldWrap: false
    });

    (
      address purchaseToken,
      uint256 purchaseTokenAmount,
      address collateralToken,
      address indexToken,
      uint256 sizeDelta,
      bool isLong,
      uint256 triggerPrice,
      bool triggerAboveThreshold
    ) = orderbook.getIncreaseOrder(ALICE, 0, 1);
    assertEq(purchaseToken, address(wbtc));
    assertEq(purchaseTokenAmount, 22500);
    assertEq(collateralToken, address(wbtc));
    assertEq(indexToken, address(wbtc));
    assertEq(sizeDelta, 47 * 10**30);
    assertTrue(isLong);
    assertEq(triggerPrice, 41_001 * 10**30);
    assertFalse(triggerAboveThreshold);
    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);

    // Execute Alice's order
    (bool shouldExecute, uint160[] memory orderList) = orderbook
      .getShouldExecuteOrderList(false, 10);
    assertTrue(shouldExecute);
    vm.warp(1669832202); // warp ahead

    // executeOrders(orderList, payable(BOB));
    PriceFeedData memory priceFeedDataStruct = PriceFeedData({
      id: WBTC_PRICE_ID,
      price: int64(4100000000000),
      conf: uint64(0),
      expo: int32(-8),
      emaPrice: int64(4100000000000),
      emaConf: uint64(0),
      publishTime: uint64(block.timestamp)
    });
    bytes memory priceFeedData = FakePyth(address(pyth))
      .createPriceFeedUpdateData({
        id: priceFeedDataStruct.id,
        price: priceFeedDataStruct.price,
        conf: priceFeedDataStruct.conf,
        expo: priceFeedDataStruct.expo,
        emaPrice: priceFeedDataStruct.emaPrice,
        emaConf: priceFeedDataStruct.emaConf,
        publishTime: priceFeedDataStruct.publishTime
      });
    bytes[] memory data = new bytes[](1);
    data[0] = priceFeedData;
    orderbook.executeIncreaseOrder(ALICE, 0, 1, payable(BOB), data);
    // Bob should receive 0.01 ether as execution fee
    assertEq(BOB.balance, 0.01 ether);

    // The following condition expected to be happened:
    // 1. Pool's WBTC liquidity should be:
    // = 234292 + 22500 - (((47 * 0.001) + (47 * 0)) / 41000)
    // = 234292 + 22500 - 114 = 256678 sathoshi
    // 2. Pool's WBTC reserved should be:
    // = 47 / 41000 = 114634 sathoshi
    // 3. Pool's WBTC guarantee USD should be:
    // = 47 + 0.047 - ((22500 / 1e8) * 41000) = 37.822 USD
    // 4. Redeemable WBTC in USD should be:
    // = ((256678 + 92248 - 114634) / 1e8) * 41000 = 96.05972 USD
    // 5. Pool's AUM by min price should be:
    // 37.822 + ((256678 - 114634) / 1e8) * 41000 = 96.06004 USD
    // 6. Pool's AUM by max price should be:
    // 37.822 + ((256678 - 114634) / 1e8) * 41000 = 96.06004 USD
    // 7. Pool should makes 706 + 114 = 820 sathoshi
    // 8. Pool's WBTC USD debt should still the same as before
    // 9. Pool's WBTC balance should be:
    // = 256678 + 820 = 257498 sathoshi
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 256678);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 114634);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 37.822 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      96.05972 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 96.06004 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 96.06004 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 820);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 257498);

    // Assert a postion
    // 1. Position's size should be 47 USD
    // 2. Position's collateral should be:
    // = ((22500 / 1e8) * 41000) - 0.047 = 9.178 USD
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
    assertEq(position.collateral, 9.178 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 114634);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);

    vm.startPrank(ALICE);
    orderbook.createDecreaseOrder{ value: 0.02 ether }({
      _subAccountId: 0,
      _indexToken: address(wbtc),
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _collateralDelta: position.collateral,
      _isLong: true,
      _triggerPrice: 44_000 * 10**30,
      _triggerAboveThreshold: true
    });
    vm.stopPrank();
    // ----- Stop Alice session ------

    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    uint256 aliceWBTCBalanceBefore = wbtc.balanceOf(ALICE);

    vm.warp(block.timestamp + 1000);

    // executeOrders(orderList, payable(BOB));
    priceFeedDataStruct = PriceFeedData({
      id: WBTC_PRICE_ID,
      price: int64(4500000000000),
      conf: uint64(0),
      expo: int32(-8),
      emaPrice: int64(4500000000000),
      emaConf: uint64(0),
      publishTime: uint64(block.timestamp)
    });
    priceFeedData = FakePyth(address(pyth)).createPriceFeedUpdateData({
      id: priceFeedDataStruct.id,
      price: priceFeedDataStruct.price,
      conf: priceFeedDataStruct.conf,
      expo: priceFeedDataStruct.expo,
      emaPrice: priceFeedDataStruct.emaPrice,
      emaConf: priceFeedDataStruct.emaConf,
      publishTime: priceFeedDataStruct.publishTime
    });
    data[0] = priceFeedData;
    orderbook.executeDecreaseOrder(ALICE, 0, 0, payable(BOB), data);
    // Bob should receive another 0.01 ether as execution fee
    assertEq(BOB.balance, 0.02 ether);

    position = poolGetterFacet.getPositionWithSubAccountId(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    // Position should be closed
    assertEq(position.collateral, 0, "Alice position should be closed");
    assertGt(
      wbtc.balanceOf(ALICE) - aliceWBTCBalanceBefore,
      22500,
      "Alice should receive collateral and profit."
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
    vm.deal(ALICE, 100 ether);
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

    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);

    // ---- Start Alice session ---- //
    vm.startPrank(ALICE);

    // Alice opens a 90 USD WBTC short position with 20 DAI as a collateral
    dai.approve(address(orderbook), 20 * 10**18);
    poolAccessControlFacet.allowPlugin(address(orderbook));
    address[] memory path = new address[](1);
    path[0] = address(dai);
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 1,
      _path: path,
      _amountIn: 20 * 10**18,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 90 * 10**30,
      _collateralToken: address(dai),
      _isLong: false,
      _triggerPrice: 49_999 * 10**30,
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: false
    });

    // Edit the trigger price of the submitted order
    orderbook.updateIncreaseOrder({
      _subAccountId: 1,
      _orderIndex: 0,
      _sizeDelta: 90 * 10**30,
      _triggerPrice: 39_999 * 10**30,
      _triggerAboveThreshold: true
    });

    (
      address purchaseToken,
      uint256 purchaseTokenAmount,
      address collateralToken,
      address indexToken,
      uint256 sizeDelta,
      bool isLong,
      uint256 triggerPrice,
      bool triggerAboveThreshold
    ) = orderbook.getIncreaseOrder(ALICE, 1, 0);
    assertEq(purchaseToken, address(dai));
    assertEq(purchaseTokenAmount, 20 * 10**18);
    assertEq(collateralToken, address(dai));
    assertEq(indexToken, address(wbtc));
    assertEq(sizeDelta, 90 * 10**30);
    assertFalse(isLong);
    assertEq(triggerPrice, 39_999 * 10**30);
    assertTrue(triggerAboveThreshold);
    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    (bool shouldExecute, uint160[] memory orderList) = orderbook
      .getShouldExecuteOrderList(false, 1);
    assertTrue(shouldExecute);
    executeOrders(orderList, payable(BOB));
    // orderbook.executeIncreaseOrder(ALICE, 1, 0, payable(BOB));
    // Bob should receive 0.01 ether as execution fee
    assertEq(BOB.balance, 0.01 ether);

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
        1,
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
      1,
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
      1,
      address(dai),
      address(wbtc),
      false
    );
    assertFalse(isProfit);
    assertEq(delta, 4.5 * 10**30);

    orderbook.createDecreaseOrder{ value: 0.01 ether }({
      _subAccountId: 1,
      _indexToken: address(wbtc),
      _sizeDelta: 90 * 10**30,
      _collateralToken: address(dai),
      _collateralDelta: position.collateral,
      _isLong: false,
      _triggerPrice: 40_000 * 10**30,
      _triggerAboveThreshold: false
    });
    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(38_000 * 10**8);

    uint256 aliceDAIBalanceBefore = dai.balanceOf(ALICE);

    (shouldExecute, orderList) = orderbook.getShouldExecuteOrderList(false, 10);
    assertTrue(shouldExecute);
    executeOrders(orderList, payable(BOB));
    // orderbook.executeDecreaseOrder(ALICE, 1, 0, payable(BOB));
    // Bob should receive another 0.01 ether as execution fee
    assertEq(BOB.balance, 0.02 ether);

    position = poolGetterFacet.getPositionWithSubAccountId(
      ALICE,
      1,
      address(wbtc),
      address(wbtc),
      true
    );
    // Position should be closed
    assertEq(position.collateral, 0, "Alice position should be closed");
    assertGt(
      dai.balanceOf(ALICE) - aliceDAIBalanceBefore,
      20 * 10**18,
      "Alice should receive collateral and profit."
    );
  }

  function testRevert_SwapOrder_InvalidPathLength() external {
    address[] memory path = new address[](1);
    path[0] = address(bnb);
    vm.expectRevert(abi.encodeWithSignature("InvalidPathLength()"));
    orderbook.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _triggerRatio: 250 * 10**30, // tokenB / tokenA
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testRevert_SwapOrder_InvalidPath() external {
    address[] memory path = new address[](2);
    path[0] = address(bnb);
    path[1] = address(bnb);
    vm.expectRevert(abi.encodeWithSignature("InvalidPath()"));
    orderbook.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _triggerRatio: 250 * 10**30, // tokenB / tokenA
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testRevert_SwapOrder_InvalidAmountIn() external {
    address[] memory path = new address[](2);
    path[0] = address(bnb);
    path[1] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InvalidAmountIn()"));
    orderbook.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 0 ether,
      _minOut: 0,
      _triggerRatio: 250 * 10**30, // tokenB / tokenA
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testRevert_SwapOrder_InsufficientExecutionFee() external {
    address[] memory path = new address[](2);
    path[0] = address(bnb);
    path[1] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InsufficientExecutionFee()"));
    orderbook.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _triggerRatio: 250 * 10**30, // tokenB / tokenA
      _triggerAboveThreshold: true,
      _executionFee: 0 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testRevert_SwapOrder_OnlyNativeShouldWrap() external {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(bnb);
    vm.expectRevert(abi.encodeWithSignature("OnlyNativeShouldWrap()"));
    orderbook.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _triggerRatio: 250 * 10**30, // tokenB / tokenA
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: true,
      _shouldUnwrap: false
    });
  }

  function testRevert_SwapOrder_IncorrectValueTransfer() external {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(bnb);
    vm.expectRevert(abi.encodeWithSignature("IncorrectValueTransfer()"));
    orderbook.createSwapOrder{ value: 0.02 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _triggerRatio: 250 * 10**30, // tokenB / tokenA
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testRevert_SwapOrder_InvalidPriceForExecution() external {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(bnb);

    wbtc.mint(ALICE, 100 ether);
    vm.deal(ALICE, 100 ether);
    vm.startPrank(ALICE);
    wbtc.approve(address(orderbook), 100 ether);
    orderbook.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _triggerRatio: 250 * 10**30, // tokenB / tokenA
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });

    vm.stopPrank();

    daiPriceFeed.setLatestAnswer(1 * 10**8);

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(600 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);

    wbtcPriceFeed.setLatestAnswer(90000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(100000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(80000 * 10**8);

    bytes[] memory data = new bytes[](1);
    vm.expectRevert(abi.encodeWithSignature("InvalidPriceForExecution()"));
    orderbook.executeSwapOrder(ALICE, 0, payable(BOB), data);
  }

  function testCorrectness_WhenSwap() external {
    orderbook.setWhitelist(address(this), false);
    orderbook.setIsAllowAllExecutor(true);

    daiPriceFeed.setLatestAnswer(1 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);

    bnb.mint(ALICE, 200 ether);
    vm.deal(address(bnb), 200 ether);
    wbtc.mint(ALICE, 1 * 10**8);

    // ------- Alice session START -------
    vm.startPrank(ALICE);

    // Alice add liquidity 200 BNB (~$60,000)
    bnb.approve(address(poolRouter), 200 ether);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(bnb), 200 ether, ALICE, 0, zeroBytesArr());

    // Alice add 200 BNB as liquidity to the pool, the following condition is expected:
    // 1. Pool should have 200 * (1-0.003) * 300 = 59820 USD in AUM
    assertEq(poolGetterFacet.getAumE18(false), 59820 ether);

    // Alice add liquidity 1 WBTC (~$60,000)
    wbtc.approve(address(poolRouter), 1 * 10**8);
    poolRouter.addLiquidity(address(wbtc), 1 * 10**8, ALICE, 0, zeroBytesArr());

    // Alice add another 1 WBTC as liquidity to the pool, the following condition is expected:
    // 1. Pool should have 59,820 + (1 * (1-0.003) * 60000) = 119,640 USD in AUM
    // 2. Alice Contract should have 119,640 ALP
    // 3. Pool should make 200 * 0.003 = 0.6 BNB in fee
    // 4. Pool should make 1 * 0.003 = 0.003 WBTC in fee
    // 5. USD debt for BNB should be 59,820 USD
    // 6. USD debt for WBTC should be 59,820 USD
    // 7. Pool's BNB liquidity should be 200 * (1-0.003) = 199.4 BNB
    // 8. Pool's WBTC liquidity should be 1 * (1-0.003) = 0.997 WBTC
    assertEq(poolGetterFacet.getAumE18(false), 119640 ether);
    assertEq(poolGetterFacet.alp().balanceOf(address(ALICE)), 119640 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(bnb)), 0.6 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 300000);
    assertEq(poolGetterFacet.usdDebtOf(address(bnb)), 59820 ether);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 59820 ether);
    assertEq(poolGetterFacet.liquidityOf(address(bnb)), 199.4 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.997 * 10**8);

    vm.stopPrank();
    // ------- Alice session END -------

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(600 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);

    wbtcPriceFeed.setLatestAnswer(90000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(100000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(80000 * 10**8);

    bnb.mint(BOB, 100 ether);
    vm.deal(address(bnb), 100 ether);
    vm.deal(BOB, 100 ether);

    // ------- Bob session START -------
    vm.startPrank(BOB);

    // Bob swap 100 BNB for WBTC
    bnb.approve(address(orderbook), 100 ether);
    address[] memory path = new address[](2);
    path[0] = address(bnb);
    path[1] = address(wbtc);
    orderbook.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _triggerRatio: 250 * 10**30, // tokenB / tokenA
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });

    (
      address path0,
      address path1,
      address path2,
      uint256 amountIn,
      uint256 minOut,
      uint256 triggerRatio,
      bool triggerAboveThreshold
    ) = orderbook.getSwapOrder(BOB, 0);

    assertEq(path0, address(bnb));
    assertEq(path1, address(wbtc));
    assertEq(path2, address(0));
    assertEq(amountIn, 100 ether);
    assertEq(minOut, 0);
    assertEq(triggerRatio, 250 * 10**30);
    assertTrue(triggerAboveThreshold);

    orderbook.cancelSwapOrder(0);
    (
      path0,
      path1,
      path2,
      amountIn,
      minOut,
      triggerRatio,
      triggerAboveThreshold
    ) = orderbook.getSwapOrder(BOB, 0);
    assertEq(triggerRatio, 0);

    bnb.approve(address(orderbook), 100 ether);
    orderbook.createSwapOrder{ value: 100.01 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _triggerRatio: 250 * 10**30, // tokenB / tokenA
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: true,
      _shouldUnwrap: false
    });

    orderbook.updateSwapOrder(1, 0, 240 * 10**30, true);

    vm.stopPrank();
    // ------- Bob session END -------
    (bool shouldExecute, uint160[] memory orderList) = orderbook
      .getShouldExecuteOrderList(false, 10);
    assertTrue(shouldExecute);
    executeOrders(orderList, payable(ALICE));
    // orderbook.executeSwapOrder(BOB, 1, payable(ALICE));
    // Alice should receive 0.01 ether as execution fee
    assertEq(ALICE.balance, 0.01 ether);

    // After Bob swap, the following condition is expected:
    // 1. Pool should have 159520 + (100 * 400) - ((100 * 400 / 100000) * 80000) = 167520 USD in AUM
    // 2. Bob should get (100 * 400 / 100000) * (1 - 0.003) = 0.3988 WBTC
    // 3. Pool should make 200 * 0.003 = 0.6 BNB in fee
    // 4. Pool should make (1 * 0.003) + ((100 * 400 / 100000) * 0.003) = 0.0042 WBTC in fee
    // 5. USD debt for BNB should be 59820 + (100 * 400) = 99820 USD
    // 6. USD debt for WBTC should be 59820 - (100 * 400) = 19820 USD
    // 7. Pool's BNB liquidity should be 199.4 + 100 = 299.4 BNB
    // 8. Pool's WBTC liquidity should be 0.997 - ((100 * 400 / 100000)) = 0.597 WBTC
    assertEq(poolGetterFacet.getAumE18(false), 167520 ether);
    assertEq(wbtc.balanceOf(BOB), 0.3988 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(bnb)), 0.6 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 0.0042 * 10**8);
    assertEq(poolGetterFacet.usdDebtOf(address(bnb)), 99820 ether);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 19820 ether);
    assertEq(poolGetterFacet.liquidityOf(address(bnb)), 299.4 ether);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.597 * 10**8);
  }

  function executeOrders(
    uint160[] memory orderList,
    address payable _executionFeeReceiver
  ) internal {
    uint256 orderLength = orderList.length / 4;

    uint256 curIndex = 0;

    bytes[] memory data = new bytes[](1);

    while (curIndex < orderLength) {
      address account = address(orderList[curIndex * 4]);
      uint256 subAccountId = uint256(orderList[curIndex * 4 + 1]);
      uint256 orderIndex = uint256(orderList[curIndex * 4 + 2]);
      uint256 orderType = uint256(orderList[curIndex * 4 + 3]);

      if (orderType == 0) {
        //SWAP
        orderbook.executeSwapOrder(
          account,
          orderIndex,
          _executionFeeReceiver,
          data
        );
      } else if (orderType == 1) {
        //INCREASE
        orderbook.executeIncreaseOrder(
          account,
          subAccountId,
          orderIndex,
          _executionFeeReceiver,
          data
        );
      } else if (orderType == 2) {
        //DECREASE
        orderbook.executeDecreaseOrder(
          account,
          subAccountId,
          orderIndex,
          _executionFeeReceiver,
          data
        );
      }
      curIndex++;
    }
  }
}
