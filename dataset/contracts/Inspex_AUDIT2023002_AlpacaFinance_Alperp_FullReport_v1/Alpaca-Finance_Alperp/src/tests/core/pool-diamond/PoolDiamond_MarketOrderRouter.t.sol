// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, console, LibPoolConfigV1, LiquidityFacetInterface, GetterFacetInterface, PerpTradeFacetInterface, FastPriceFeed } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_MarketOrderRouter is PoolDiamond_BaseTest {
  FastPriceFeed internal fastPriceFeed;

  // MarketOrderRouter.CreateSwapOrder
  event CancelSwapOrder(
    address account,
    address[] path,
    uint256 amountIn,
    uint256 minOut,
    bool shouldUnwrap,
    uint256 executionFee,
    uint256 blockGap,
    uint256 timeGap,
    uint256 queueIndex
  );

  function setUp() public override {
    super.setUp();

    (
      address[] memory tokens2,
      LibPoolConfigV1.TokenConfig[] memory tokenConfigs2
    ) = buildDefaultSetTokenConfigInput2();

    poolAdminFacet.setTokenConfigs(tokens2, tokenConfigs2);
    marketOrderRouter.setAdmin(address(this));
    marketOrderRouter.setPositionKeeper(address(this), true);

    // Fast price feed batch
    fastPriceFeed = deployFastPriceFeed(
      300,
      3600,
      0,
      1000,
      address(this),
      address(marketOrderRouter),
      address(orderbook)
    );

    address[] memory _signers = new address[](1);
    _signers[0] = address(this);
    address[] memory _updaters = new address[](1);
    _updaters[0] = address(this);
    fastPriceFeed.init(1, _signers, _updaters);
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
    fastPriceFeed.setConfigs(
      _tokens,
      _tokenPrecisions,
      1,
      60,
      _maxCumulativeDeltaDiffs,
      3600,
      500,
      20
    );

    poolOracle.setSecondaryPriceFeed(address(fastPriceFeed));
    poolOracle.setIsSecondaryPriceEnabled(true);
    marketOrderRouter.setPositionKeeper(address(fastPriceFeed), true);
  }

  function testRevert_CreateIncreasePosition_WithInsufficientExecutionFee()
    external
  {
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InsufficientExecutionFee()"));
    marketOrderRouter.createIncreasePosition{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _amountIn: 22500,
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _acceptablePrice: 41_001 * 10**30,
      _executionFee: 0 ether
    });
  }

  function testRevert_CreateIncreasePosition_WithIncorrectValueTransferred()
    external
  {
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("IncorrectValueTransferred()"));
    marketOrderRouter.createIncreasePosition{ value: 0.001 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _amountIn: 22500,
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _acceptablePrice: 41_001 * 10**30,
      _executionFee: 0.01 ether
    });
  }

  function testRevert_IncreasePosition_WithInvalidPathLength() external {
    address[] memory path = new address[](3);
    path[0] = address(wbtc);
    path[1] = address(wbtc);
    path[2] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InvalidPathLength()"));
    marketOrderRouter.createIncreasePosition{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _amountIn: 22500,
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _acceptablePrice: 41_001 * 10**30,
      _executionFee: 0.01 ether
    });
  }

  function testRevert_CreateIncreasePositionNative_WithInsufficientExecutionFee()
    external
  {
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InsufficientExecutionFee()"));
    marketOrderRouter.createIncreasePositionNative{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _acceptablePrice: 41_001 * 10**30,
      _executionFee: 0 ether
    });
  }

  function testRevert_CreateIncreasePositionNative_WithIncorrectValueTransferred()
    external
  {
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("IncorrectValueTransferred()"));
    marketOrderRouter.createIncreasePositionNative{ value: 0.001 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _acceptablePrice: 41_001 * 10**30,
      _executionFee: 0.01 ether
    });
  }

  function testRevert_IncreasePositionNative_WithInvalidPathLength() external {
    address[] memory path = new address[](3);
    path[0] = address(weth);
    path[1] = address(wbtc);
    path[2] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InvalidPathLength()"));
    marketOrderRouter.createIncreasePositionNative{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _acceptablePrice: 41_001 * 10**30,
      _executionFee: 0.01 ether
    });
  }

  function testRevert_IncreasePositionNative_WhenStartPathIsNotWrapNative()
    external
  {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InvalidPath()"));
    marketOrderRouter.createIncreasePositionNative{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _acceptablePrice: 41_001 * 10**30,
      _executionFee: 0.01 ether
    });
  }

  function testRevert_CreateDecreasePosition_WithInsufficientExecutionFee()
    external
  {
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InsufficientExecutionFee()"));
    marketOrderRouter.createDecreasePosition{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _collateralDelta: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _receiver: address(this),
      _acceptablePrice: 41_001 * 10**30,
      _minOut: 0,
      _executionFee: 0 ether,
      _withdrawETH: false
    });
  }

  function testRevert_CreateDecreasePosition_WithIncorrectValueTransferred()
    external
  {
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("IncorrectValueTransferred()"));
    marketOrderRouter.createDecreasePosition{ value: 0.001 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _collateralDelta: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _receiver: address(this),
      _acceptablePrice: 41_001 * 10**30,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _withdrawETH: false
    });
  }

  function testRevert_CreateDecreasePosition_WithInvalidPathLength() external {
    address[] memory path = new address[](3);
    path[0] = address(wbtc);
    path[1] = address(wbtc);
    path[2] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InvalidPathLength()"));
    marketOrderRouter.createDecreasePosition{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _collateralDelta: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _receiver: address(this),
      _acceptablePrice: 41_001 * 10**30,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _withdrawETH: false
    });
  }

  function testRevert_CreateDecreasePosition_WhenWithdrawETHIsTrue_WhenLastPathIsNotWNative()
    external
  {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InvalidPath()"));
    marketOrderRouter.createDecreasePosition{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _collateralDelta: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _receiver: address(this),
      _acceptablePrice: 41_001 * 10**30,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _withdrawETH: true
    });
  }

  function testRevert_CreateSwapOrder_WithInvalidPathLength() external {
    address[] memory path = new address[](3);
    path[0] = address(wbtc);
    path[1] = address(weth);
    path[2] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InvalidPathLength()"));
    marketOrderRouter.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 1 ether,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testRevert_CreateSwapOrder_WithInvalidPath() external {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(wbtc);
    vm.expectRevert(abi.encodeWithSignature("InvalidPath()"));
    marketOrderRouter.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 1 ether,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testRevert_CreateSwapOrder_WithAmountInEQZero() external {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(weth);
    vm.expectRevert(abi.encodeWithSignature("InvalidAmountIn()"));
    marketOrderRouter.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 0 ether,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testRevert_CreateSwapOrder_WithInsufficientExecutionFee() external {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(weth);
    vm.expectRevert(abi.encodeWithSignature("InsufficientExecutionFee()"));
    marketOrderRouter.createSwapOrder{ value: 0.01 ether }({
      _path: path,
      _amountIn: 1 ether,
      _minOut: 0,
      _executionFee: 0.001 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testRevert_CreateSwapOrder_WithStartPathIsNotWNative_WithShouldWrap()
    external
  {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(weth);
    vm.expectRevert(abi.encodeWithSignature("OnlyNativeShouldWrap()"));
    marketOrderRouter.createSwapOrder{ value: 1.01 ether }({
      _path: path,
      _amountIn: 1 ether,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _shouldWrap: true,
      _shouldUnwrap: false
    });
  }

  function testRevert_CreateSwapOrder_WithIncorrectValueTransferred_WithShouldWrap()
    external
  {
    address[] memory path = new address[](2);
    path[0] = address(bnb);
    path[1] = address(weth);
    vm.expectRevert(abi.encodeWithSignature("IncorrectValueTransferred()"));
    marketOrderRouter.createSwapOrder{ value: 1.02 ether }({
      _path: path,
      _amountIn: 1 ether,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _shouldWrap: true,
      _shouldUnwrap: false
    });
  }

  function testRevert_CreateSwapOrder_WithIncorrectValueTransferred_WithShouldNotWrap()
    external
  {
    address[] memory path = new address[](2);
    path[0] = address(wbtc);
    path[1] = address(weth);
    // approve 1 ether of wbtc
    wbtc.approve(address(marketOrderRouter), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("IncorrectValueTransferred()"));
    marketOrderRouter.createSwapOrder{ value: 0.001 ether }({
      _path: path,
      _amountIn: 1 ether,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });
  }

  function testCorrectness_WhenLong_WithNoSwap_WithoutDepositFee() external {
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

    uint256 startTime = 1669832202;
    vm.warp(startTime);
    // Alice increase long position with sub account id = 0
    vm.startPrank(ALICE);
    wbtc.approve(address(marketOrderRouter), 22500);
    poolAccessControlFacet.allowPlugin(address(marketOrderRouter));
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    bytes32 requestKey = marketOrderRouter.createIncreasePosition{
      value: 0.01 ether
    }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _amountIn: 22500,
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _acceptablePrice: 41_001 * 10**30,
      _executionFee: 0.01 ether
    });
    vm.stopPrank();

    {
      // Avoid Stack-Too-Deep
      (
        address actualAccount,
        uint256 actualSubAccountId,
        address actualIndexToken,
        uint256 actualAmountIn,
        uint256 actualMinOut,
        uint256 actualSizeDelta,
        bool actualIsLong,
        uint256 actualAcceptablePrice,
        uint256 actualExecutionFee,
        uint256 actualBlockNumber,
        uint256 actualBlockTime,
        bool actualHasCollateralInETH
      ) = marketOrderRouter.increasePositionRequests(requestKey);

      assertEq(actualAccount, address(ALICE));
      assertEq(actualSubAccountId, 0);
      assertEq(actualIndexToken, address(wbtc));
      assertEq(actualAmountIn, 22500);
      assertEq(actualMinOut, 0);
      assertEq(actualSizeDelta, 47 * 10**30);
      assertTrue(actualIsLong);
      assertEq(actualAcceptablePrice, 41_001 * 10**30);
      assertEq(actualExecutionFee, 0.01 ether);
      assertEq(actualBlockNumber, block.number);
      assertEq(actualBlockTime, block.timestamp);
      assertFalse(actualHasCollateralInETH);
    }

    {
      // Avoid Stack-Too-Deep
      address[] memory actualPath = marketOrderRouter
        .getIncreasePositionRequestPath(requestKey);
      assertEq(actualPath[0], path[0]);
    }

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Set delay values for execution validation
    marketOrderRouter.setDelayValues({
      _minBlockDelayKeeper: 0,
      _minTimeDelayPublic: 3 minutes,
      _maxTimeDelay: 30 minutes
    });

    // Execute Alice's order
    (
      ,
      uint256 increaseQueueEndIndex,
      ,
      uint256 decreaseQueueEndIndex,
      ,
      uint256 swapOrderQueueEndIndex
    ) = marketOrderRouter.getRequestQueueLengths();

    vm.warp(block.timestamp + 1 minutes); // warp ahead to prevent FastPriceFeed failure in checking last update validation
    fastPriceFeed.setPricesWithBitsAndExecute(
      getPriceBits(41000000, 1200000, 870),
      block.timestamp,
      increaseQueueEndIndex,
      decreaseQueueEndIndex,
      swapOrderQueueEndIndex,
      1,
      1,
      1,
      payable(BOB),
      0x0000000000000000000000000000000000000000000000000000000000000000
    );

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
    marketOrderRouter.createDecreasePosition{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _indexToken: address(wbtc),
      _collateralDelta: position.collateral,
      _sizeDelta: 47 * 10**30,
      _isLong: true,
      _receiver: address(ALICE),
      _acceptablePrice: 44_000 * 10**30,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _withdrawETH: false
    });
    vm.stopPrank();
    // ----- Stop Alice session ------

    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(46_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);

    uint256 aliceWBTCBalanceBefore = wbtc.balanceOf(ALICE);

    // Execute Alice's order
    (
      ,
      increaseQueueEndIndex,
      ,
      decreaseQueueEndIndex,
      ,
      swapOrderQueueEndIndex
    ) = marketOrderRouter.getRequestQueueLengths();

    vm.warp(block.timestamp + 1000);
    fastPriceFeed.setPricesWithBitsAndExecute(
      getPriceBits(45000000, 1200000, 870),
      block.timestamp,
      increaseQueueEndIndex,
      decreaseQueueEndIndex,
      swapOrderQueueEndIndex,
      1,
      1,
      1,
      payable(BOB),
      0x0000000000000000000000000000000000000000000000000000000000000000
    );

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

  function testCorrectness_WhenShort_WithNoSwap_WithoutDepositFee() external {
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
    dai.approve(address(marketOrderRouter), 20 * 10**18);
    poolAccessControlFacet.allowPlugin(address(marketOrderRouter));
    address[] memory path = new address[](1);
    path[0] = address(dai);
    bytes32 requestKey = marketOrderRouter.createIncreasePosition{
      value: 0.01 ether
    }({
      _subAccountId: 1,
      _path: path,
      _indexToken: address(wbtc),
      _amountIn: 20 * 10**18,
      _minOut: 0,
      _sizeDelta: 90 * 10**30,
      _isLong: false,
      _acceptablePrice: 39_999 * 10**30,
      _executionFee: 0.01 ether
    });
    vm.stopPrank();

    {
      // Avoid Stack-Too-Deep
      (
        address actualAccount,
        uint256 actualSubAccountId,
        address actualIndexToken,
        uint256 actualAmountIn,
        uint256 actualMinOut,
        uint256 actualSizeDelta,
        bool actualIsLong,
        uint256 actualAcceptablePrice,
        uint256 actualExecutionFee,
        uint256 actualBlockNumber,
        uint256 actualBlockTime,
        bool actualHasCollateralInETH
      ) = marketOrderRouter.increasePositionRequests(requestKey);

      assertEq(actualAccount, address(ALICE));
      assertEq(actualSubAccountId, 1);
      assertEq(actualIndexToken, address(wbtc));
      assertEq(actualAmountIn, 20 * 10**18);
      assertEq(actualMinOut, 0);
      assertEq(actualSizeDelta, 90 * 10**30);
      assertFalse(actualIsLong);
      assertEq(actualAcceptablePrice, 39_999 * 10**30);
      assertEq(actualExecutionFee, 0.01 ether);
      assertEq(actualBlockNumber, block.number);
      assertEq(actualBlockTime, block.timestamp);
      assertFalse(actualHasCollateralInETH);
    }

    {
      // Avoid Stack-Too-Deep
      address[] memory actualPath = marketOrderRouter
        .getIncreasePositionRequestPath(requestKey);
      assertEq(actualPath[0], path[0]);
    }

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Set delay values for execution validation
    marketOrderRouter.setDelayValues({
      _minBlockDelayKeeper: 0,
      _minTimeDelayPublic: 3 minutes,
      _maxTimeDelay: 30 minutes
    });

    // Execute Alice's order
    (, uint256 increaseQueueEndIndex, , , , ) = marketOrderRouter
      .getRequestQueueLengths();
    marketOrderRouter.executeIncreasePositions(
      increaseQueueEndIndex,
      payable(address(BOB))
    );
    // Bob should receive 0.01 ether as execution fee
    assertEq(BOB.balance, 0.01 ether);

    // // The following conditions need to be met:
    // // 1. Pool's DAI liquidity should be the same.
    // // 2. Pool's DAI USD debt should be the same.
    // // 2. Pool's DAI reserved should be 90 DAI
    // // 3. Pool's guaranteed USD should be 0
    // // 4. Redemptable DAI collateral should be 499.8 USD (same as liquidity)
    // // 5. Pool should makes 0.2 + ((90 * 0.001)) = 0.29 DAI
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

    // // Assert a position:
    // // 1. Position's size should be 90
    // // 2. Position's collateral should be 20 - (90 * 0.001) = 19.91 DAI
    // // 3. Position's averagePrice should be 40,000 USD
    // // 4. Position's entry funding rate should be 0
    // // 5. Position's reserve amount should be 90 DAI
    // // 6. Position should be in profit
    // // 7. Position's lastIncreasedTime should be block.timestamp
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

    marketOrderRouter.createDecreasePosition{ value: 0.01 ether }({
      _subAccountId: 1,
      _path: path,
      _indexToken: address(wbtc),
      _collateralDelta: position.collateral,
      _sizeDelta: 90 * 10**30,
      _isLong: false,
      _receiver: address(ALICE),
      _acceptablePrice: 40_000 * 10**30,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _withdrawETH: false
    });
    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(38_000 * 10**8);

    uint256 aliceDAIBalanceBefore = dai.balanceOf(ALICE);

    // Execute Alice's order
    (, , , uint256 decreaseQueueEndIndex, , ) = marketOrderRouter
      .getRequestQueueLengths();
    marketOrderRouter.executeDecreasePositions(
      decreaseQueueEndIndex,
      payable(address(BOB))
    );

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

  function testCorrectness_WhenSwap() external {
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
    bnb.approve(address(marketOrderRouter), 100 ether);
    address[] memory path = new address[](2);
    path[0] = address(bnb);
    path[1] = address(wbtc);
    bytes32 requestKey = marketOrderRouter.createSwapOrder{
      value: 0.01 ether
    }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _shouldWrap: false,
      _shouldUnwrap: false
    });

    {
      // Avoid Stack-Too-Deep
      (
        address actualAccount,
        uint256 actualAmountIn,
        uint256 actualMinOut,
        bool actualShouldUnwrap,
        uint256 actualExecutionFee,
        uint256 actualBlockNumber,
        uint256 actualBlockTime
      ) = marketOrderRouter.swapOrderRequests(requestKey);

      assertEq(actualAccount, address(BOB));
      assertEq(actualAmountIn, 100 ether);
      assertEq(actualMinOut, 0);
      assertFalse(actualShouldUnwrap);
      assertEq(actualExecutionFee, 0.01 ether);
      assertEq(actualBlockNumber, block.number);
      assertEq(actualBlockTime, block.timestamp);
    }

    {
      // Avoid Stack-Too-Deep
      address[] memory actualPath = marketOrderRouter.getSwapOrderRequestPath(
        requestKey
      );
      assertEq(actualPath[0], path[0]);
      assertEq(actualPath[1], path[1]);
    }

    uint256 BobBNBBalanceBefore = BOB.balance;
    marketOrderRouter.cancelSwapOrder(requestKey, payable(BOB), 1);

    {
      // Avoid Stack-Too-Deep
      (
        address actualAccount,
        uint256 actualAmountIn,
        uint256 actualMinOut,
        bool actualShouldUnwrap,
        uint256 actualExecutionFee,
        uint256 actualBlockNumber,
        uint256 actualBlockTime
      ) = marketOrderRouter.swapOrderRequests(requestKey);

      assertEq(actualAccount, address(0));
      assertEq(actualAmountIn, 0);
      assertEq(actualMinOut, 0);
      assertFalse(actualShouldUnwrap);
      assertEq(actualExecutionFee, 0);
      assertEq(actualBlockNumber, 0);
      assertEq(actualBlockTime, 0);
    }

    assertEq(BOB.balance - BobBNBBalanceBefore, 100.01 ether);

    uint256 startTime = 1669832202;
    vm.warp(startTime);
    bnb.approve(address(marketOrderRouter), 100 ether);
    requestKey = marketOrderRouter.createSwapOrder{ value: 100.01 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _shouldWrap: true,
      _shouldUnwrap: false
    });

    vm.stopPrank();
    // ------- Bob session END -------

    // Set delay values for execution validation
    marketOrderRouter.setDelayValues({
      _minBlockDelayKeeper: 0,
      _minTimeDelayPublic: 3 minutes,
      _maxTimeDelay: 30 minutes
    });

    vm.warp(block.timestamp + 1 minutes);

    // Execute Bob's order
    (
      ,
      uint256 increaseQueueEndIndex,
      ,
      uint256 decreaseQueueEndIndex,
      ,
      uint256 swapOrderQueueEndIndex
    ) = marketOrderRouter.getRequestQueueLengths();

    vm.warp(block.timestamp + 30 minutes);

    // Timeout since max time delay is 30 mins
    BobBNBBalanceBefore = BOB.balance;


    vm.expectEmit(false, false, false, true);
    emit CancelSwapOrder(
      BOB,
      path,
      100 ether,
      0,
      false,
      0.01 ether,
      0,
      31 minutes,
      swapOrderQueueEndIndex - 1
    );

    fastPriceFeed.setPricesWithBitsAndExecute(
      getPriceBits(100000000, 1200000, 400000),
      block.timestamp,
      increaseQueueEndIndex,
      decreaseQueueEndIndex,
      swapOrderQueueEndIndex,
      1,
      1,
      2, // included canceled orders as well
      payable(ALICE),
      0x0000000000000000000000000000000000000000000000000000000000000000
    );

    // Since block number exceeds delay value, instead of execution, the order will be cancelled
    {
      // Avoid Stack-Too-Deep
      (
        address actualAccount,
        uint256 actualAmountIn,
        uint256 actualMinOut,
        bool actualShouldUnwrap,
        uint256 actualExecutionFee,
        uint256 actualBlockNumber,
        uint256 actualBlockTime
      ) = marketOrderRouter.swapOrderRequests(requestKey);

      assertEq(actualAccount, address(0));
      assertEq(actualAmountIn, 0);
      assertEq(actualMinOut, 0);
      assertFalse(actualShouldUnwrap);
      assertEq(actualExecutionFee, 0);
      assertEq(actualBlockNumber, 0);
      assertEq(actualBlockTime, 0);
    }
    // Alice will receive execution fee regardless of the fact the the order is cancelled
    assertEq(BOB.balance - BobBNBBalanceBefore, 100 ether);
    assertEq(ALICE.balance, 0.01 ether);

    // Bob try to create an order once again
    // ------- Bob session START -------
    vm.startPrank(BOB);

    bnb.approve(address(marketOrderRouter), 100 ether);
    requestKey = marketOrderRouter.createSwapOrder{ value: 100.01 ether }({
      _path: path,
      _amountIn: 100 ether,
      _minOut: 0,
      _executionFee: 0.01 ether,
      _shouldWrap: true,
      _shouldUnwrap: false
    });
    vm.stopPrank();
    // ------- Bob session END -------

    // Set delay values for execution validation
    marketOrderRouter.setDelayValues({
      _minBlockDelayKeeper: 0,
      _minTimeDelayPublic: 3 minutes,
      _maxTimeDelay: 30 minutes
    });

    vm.warp(block.timestamp + 1 minutes);

    // Execute Bob's order
    (
      ,
      increaseQueueEndIndex,
      ,
      decreaseQueueEndIndex,
      ,
      swapOrderQueueEndIndex
    ) = marketOrderRouter.getRequestQueueLengths();

    fastPriceFeed.setPricesWithBitsAndExecute(
      getPriceBits(100000000, 1200000, 400000),
      block.timestamp,
      increaseQueueEndIndex,
      decreaseQueueEndIndex,
      swapOrderQueueEndIndex,
      1,
      1,
      3, // included canceled orders as well
      payable(ALICE),
      0x0000000000000000000000000000000000000000000000000000000000000000
    );
    // 0.01 from the previous cancellation + 0.01 from the current execution
    assertEq(ALICE.balance, 0.02 ether);

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
}
