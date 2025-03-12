// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// contracts
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";
import { IChainlinkAggregator } from "src/interfaces/IChainlinkAggregator.sol";

// libraries
import { LibLiquidityAmounts } from "src/libraries/LibLiquidityAmounts.sol";
import { LibTickMath } from "src/libraries/LibTickMath.sol";

// fixtures
import "test/fixtures/BscFixture.f.sol";
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PancakeV3VaultOracleHarness is PancakeV3VaultOracle {
  function harness_getPositionValueUSD(
    address _pool,
    uint256 _tokenId,
    uint256 _token0OraclePrice,
    uint256 _token1OraclePrice
  ) external view returns (uint256) {
    return _getPositionValueUSD(_pool, _tokenId, _token0OraclePrice, _token1OraclePrice);
  }
}

contract PancakeV3VaultOracleTest is BscFixture, ProtocolActorFixture {
  int24 constant MIN_TICK = -887272;
  int24 constant MAX_TICK = 887272;

  PancakeV3VaultOracle oracle;
  PancakeV3VaultOracleHarness harness;
  address mockBank = makeAddr("mockBank");
  address mockVaultToken = makeAddr("mockVaultToken");
  address mockWorker = makeAddr("mockWorker");

  constructor() BscFixture() ProtocolActorFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    vm.startPrank(DEPLOYER);
    harness = PancakeV3VaultOracleHarness(
      DeployHelper.deployUpgradeableFullPath(
        "./out/PancakeV3VaultOracle.t.sol/PancakeV3VaultOracleHarness.json",
        abi.encodeWithSelector(
          PancakeV3VaultOracle.initialize.selector, address(pancakeV3PositionManager), mockBank, 10000, 10_500
        )
      )
    );
    oracle = PancakeV3VaultOracle(
      DeployHelper.deployUpgradeable(
        "PancakeV3VaultOracle",
        abi.encodeWithSelector(
          PancakeV3VaultOracle.initialize.selector, address(pancakeV3PositionManager), mockBank, 10000, 10_500
        )
      )
    );
    oracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
    oracle.setPriceFeedOf(address(doge), address(dogeFeed));
    oracle.setPriceFeedOf(address(usdt), address(usdtFeed));
    vm.stopPrank();
  }

  function _addLiquidity(
    ICommonV3Pool pool,
    int24 tickLower,
    int24 tickUpper,
    uint256 amount0Desired,
    uint256 amount1Desired
  ) internal returns (uint256 tokenId, uint256 amount0, uint256 amount1) {
    deal(pool.token0(), address(this), amount0Desired);
    deal(pool.token1(), address(this), amount1Desired);

    IERC20(pool.token0()).approve(address(pancakeV3PositionManager), type(uint256).max);
    IERC20(pool.token1()).approve(address(pancakeV3PositionManager), type(uint256).max);

    (tokenId,, amount0, amount1) = pancakeV3PositionManager.mint(
      ICommonV3PositionManager.MintParams({
        token0: pool.token0(),
        token1: pool.token1(),
        fee: pool.fee(),
        tickLower: tickLower,
        tickUpper: tickUpper,
        amount0Desired: amount0Desired,
        amount1Desired: amount1Desired,
        amount0Min: 0,
        amount1Min: 0,
        recipient: address(this),
        deadline: block.timestamp
      })
    );
  }

  function testCorrectness_SetMaxPriceDiff() public {
    vm.prank(DEPLOYER);
    oracle.setMaxPriceDiff(10_000);
    assertEq(oracle.maxPriceDiff(), 10_000);
  }

  function testRevert_SetMaxPriceDiff_InvalidValue() public {
    vm.prank(DEPLOYER);
    vm.expectRevert(abi.encodeWithSignature("PancakeV3VaultOracle_InvalidParams()"));
    oracle.setMaxPriceDiff(9999);
  }

  function testRevert_SetMaxPriceDiff_NotOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    oracle.setMaxPriceDiff(10_000);
  }

  // TODO; enable this when revisit oracle
  // struct TestGetPositionValueParams {
  //   ICommonV3Pool pool;
  //   IChainlinkAggregator token0Feed;
  //   IChainlinkAggregator token1Feed;
  //   int24 tickLower;
  //   int24 tickUpper;
  //   uint256 amount0Desired;
  //   uint256 amount1Desired;
  // }

  // function _testGetPositionValue(TestGetPositionValueParams memory params) internal {
  //   (uint256 tokenId, uint256 amount0, uint256 amount1) =
  //     _addLiquidity(params.pool, params.tickLower, params.tickUpper, params.amount0Desired, params.amount1Desired);
  //   (, int256 token0Price,,,) = params.token0Feed.latestRoundData();
  //   (, int256 token1Price,,,) = params.token1Feed.latestRoundData();

  //   uint256 positionValueUSD = harness.harness_getPositionValueUSD(
  //     address(params.pool),
  //     tokenId,
  //     uint256(token0Price) * (10 ** (18 - params.token0Feed.decimals())),
  //     uint256(token1Price) * (10 ** (18 - params.token1Feed.decimals()))
  //   );

  //   uint256 token0ValueUSD = amount0 * (10 ** (18 - IERC20(params.pool.token0()).decimals())) * uint256(token0Price)
  //     / (10 ** params.token0Feed.decimals());
  //   uint256 token1ValueUSD = amount1 * (10 ** (18 - IERC20(params.pool.token1()).decimals())) * uint256(token1Price)
  //     / (10 ** params.token1Feed.decimals());
  //   uint256 expectedPositionValueUSD = token0ValueUSD + token1ValueUSD;

  //   // FIXME find other method to calculate expected amount so there is minimal delta
  //   assertApproxEqRel(positionValueUSD, expectedPositionValueUSD, 1e16);
  // }

  // function testForkFuzz_Harness_GetPositionValueUSD_InRange_E18Tokens(
  //   int24 tickLower,
  //   int24 tickUpper,
  //   uint256 amount0Desired,
  //   uint256 amount1Desired
  // ) public {
  //   // Assume fuzz inputs
  //   (uint160 sqrtPriceX96Current, int24 tickCurrent,,,,,) = pancakeV3USDTWBNBPool.slot0();
  //   // Bound to valid tick in range
  //   tickLower = int24(bound(tickLower, MIN_TICK, tickCurrent - 1));
  //   tickUpper = int24(bound(tickUpper, tickCurrent + 1, MAX_TICK));
  //   // Round tick to nearest valid tick according to tick spacing
  //   int24 tickSpacing = pancakeV3USDTWBNBPool.tickSpacing();
  //   tickLower = tickLower + tickSpacing - tickLower % tickSpacing;
  //   tickUpper = tickUpper - tickSpacing - tickUpper % tickSpacing;
  //   // Bound to sensible amount
  //   amount0Desired = bound(amount0Desired, 1e6, 1e32);
  //   amount1Desired = bound(amount1Desired, 1e6, 1e32);
  //   // Assume liquidity != 0
  //   vm.assume(
  //     LibLiquidityAmounts.getLiquidityForAmounts(
  //       sqrtPriceX96Current,
  //       LibTickMath.getSqrtRatioAtTick(tickLower),
  //       LibTickMath.getSqrtRatioAtTick(tickUpper),
  //       amount0Desired,
  //       amount1Desired
  //     ) != 0
  //   );

  //   _testGetPositionValue(
  //     TestGetPositionValueParams({
  //       pool: pancakeV3USDTWBNBPool,
  //       token0Feed: usdtFeed,
  //       token1Feed: wbnbFeed,
  //       tickLower: tickLower,
  //       tickUpper: tickUpper,
  //       amount0Desired: amount0Desired,
  //       amount1Desired: amount1Desired
  //     })
  //   );
  // }

  // function testForkFuzz_Harness_GetPositionValueUSD_InRange_NonE18Tokens(
  //   int24 tickLower,
  //   int24 tickUpper,
  //   uint256 amount0Desired,
  //   uint256 amount1Desired
  // ) public {
  //   // Assume fuzz inputs
  //   (uint160 sqrtPriceX96Current, int24 tickCurrent,,,,,) = pancakeV3DOGEWBNBPool.slot0();
  //   // Bound to valid tick in range
  //   tickLower = int24(bound(tickLower, MIN_TICK, tickCurrent - 1));
  //   tickUpper = int24(bound(tickUpper, tickCurrent + 1, MAX_TICK));
  //   // Round tick to nearest valid tick according to tick spacing
  //   int24 tickSpacing = pancakeV3DOGEWBNBPool.tickSpacing();
  //   tickLower = tickLower + tickSpacing - tickLower % tickSpacing;
  //   tickUpper = tickUpper - tickSpacing - tickUpper % tickSpacing;
  //   // Bound to sensible amount
  //   amount0Desired = bound(amount0Desired, 1e6, 1e28);
  //   amount1Desired = bound(amount1Desired, 1e6, 1e32);
  //   // Assume liquidity != 0
  //   vm.assume(
  //     LibLiquidityAmounts.getLiquidityForAmounts(
  //       sqrtPriceX96Current,
  //       LibTickMath.getSqrtRatioAtTick(tickLower),
  //       LibTickMath.getSqrtRatioAtTick(tickUpper),
  //       amount0Desired,
  //       amount1Desired
  //     ) != 0
  //   );

  //   _testGetPositionValue(
  //     TestGetPositionValueParams({
  //       pool: pancakeV3DOGEWBNBPool,
  //       token0Feed: dogeFeed,
  //       token1Feed: wbnbFeed,
  //       tickLower: tickLower,
  //       tickUpper: tickUpper,
  //       amount0Desired: amount0Desired,
  //       amount1Desired: amount1Desired
  //     })
  //   );
  // }

  // TODO: convert to fuzz test
  function testCorrectness_GetEquityAndDebt() public {
    (, int256 wbnbAnswer,,,) = wbnbFeed.latestRoundData();
    (, int256 dogeAnswer,,,) = dogeFeed.latestRoundData();

    // Mock position
    uint256 expectedPositionValue;
    {
      int24 tickLower = 0;
      int24 tickUpper = 10_000;
      uint256 wbnbAddLiquidity = 1 ether;
      uint256 dogeAddLiquidity = 1e8;
      (uint256 tokenId, uint256 amount0, uint256 amount1) =
        _addLiquidity(pancakeV3DOGEWBNBPool, tickLower, tickUpper, dogeAddLiquidity, wbnbAddLiquidity);
      vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3DOGEWBNBPool)));
      vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(tokenId));
      // Calculate expected position value
      // 1e2 = 1e10 (pad doge amount to 18 decimals) - 1e8 (feed decimals)
      expectedPositionValue = amount0 * uint256(dogeAnswer) * 1e2 + amount1 * uint256(wbnbAnswer) / 1e8;
    }

    // Mock debt
    uint256 wbnbDebt = 1 ether;
    uint256 dogeDebt = 1e8;
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(doge)),
      abi.encode(0, dogeDebt)
    );
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(wbnb)),
      abi.encode(0, wbnbDebt)
    );
    // Calculate expected debt value
    uint256 expectedDebtValue = dogeDebt * uint256(dogeAnswer) * 1e2 + wbnbDebt * uint256(wbnbAnswer) / 1e8;

    // Mock token balance
    uint256 wbnbBalance = 1 ether;
    uint256 dogeBalance = 1e8;
    deal(address(wbnb), mockWorker, wbnbBalance);
    deal(address(doge), mockWorker, dogeBalance);
    // Calculate expected token value
    uint256 expectedTokenValue = dogeBalance * uint256(dogeAnswer) * 1e2 + wbnbBalance * uint256(wbnbAnswer) / 1e8;

    // emit log_named_decimal_uint("expectedPositionValue ", expectedPositionValue, 18);
    // emit log_named_decimal_uint("expectedDebtValue     ", expectedDebtValue, 18);
    // emit log_named_decimal_uint("expectedTokenValue    ", expectedTokenValue, 18);

    // Assert
    (uint256 equity, uint256 debtValue) = oracle.getEquityAndDebt(mockVaultToken, mockWorker);
    assertApproxEqRel(expectedPositionValue + expectedTokenValue - expectedDebtValue, equity, 1);
    assertEq(expectedDebtValue, debtValue);
  }

  function testCorrectness_GetExposure_WithPosition() public {
    (uint256 tokenId,, uint256 expectedAmount1Farm) =
      _addLiquidity(pancakeV3USDTWBNBPool, -59870, -56860, 300 ether, 1 ether);
    vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3USDTWBNBPool)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(tokenId));
    vm.mockCall(mockWorker, abi.encodeWithSignature("isToken0Base()"), abi.encode(true));
    uint256 expectedAmount1Undeployed = 1 ether;
    deal(address(wbnb), mockWorker, expectedAmount1Undeployed);
    uint256 expectedAmount1Debt = 1.5 ether;
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(wbnb)),
      abi.encode(0, expectedAmount1Debt)
    );

    int256 exposure = oracle.getExposure(mockVaultToken, mockWorker);
    assertApproxEqRel(
      exposure,
      int256(expectedAmount1Farm + expectedAmount1Undeployed - expectedAmount1Debt),
      0.006635307640418746 ether // actual < expected about 0.66%
    );
  }

  function testCorrectness_GetExposure_NoPosition() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3USDTWBNBPool)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(0));
    vm.mockCall(mockWorker, abi.encodeWithSignature("isToken0Base()"), abi.encode(true));
    uint256 expectedAmount1Undeployed = 1 ether;
    deal(address(wbnb), mockWorker, expectedAmount1Undeployed);
    uint256 expectedAmount1Debt = 0.1 ether;
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(wbnb)),
      abi.encode(0, expectedAmount1Debt)
    );

    int256 exposure = oracle.getExposure(mockVaultToken, mockWorker);
    assertEq(exposure, int256(expectedAmount1Undeployed - expectedAmount1Debt));
  }

  // TODO: fuzz out range
  //   function testForkFuzz_Harness_GetPositionValueUSD_OutOfLowerRange_E18Tokens(
  //     int24 tickLower,
  //     int24 tickUpper,
  //     uint256 amount1Desired
  //   ) public {
  //     // Assume fuzz inputs
  //     (uint160 sqrtPriceX96Current, int24 tickCurrent,,,,,) = pancakeV3USDTWBNBPool.slot0();
  //     // Bound to tick out of lower range and round to nearest valid tick according to tickSpacing
  //     int24 tickSpacing = pancakeV3USDTWBNBPool.tickSpacing();
  //     tickUpper = int24(bound(tickUpper, MIN_TICK + 2 * tickSpacing, tickCurrent));
  //     tickUpper = tickUpper - tickUpper % tickSpacing;
  //     tickLower = int24(bound(tickLower, MIN_TICK, tickUpper));
  //     tickLower = tickLower + tickSpacing - tickLower % tickSpacing;
  //     // Bound to sensible amount
  //     amount1Desired = bound(amount1Desired, 1e8, 1e12);
  //     vm.assume(
  //       LibLiquidityAmounts.getLiquidityForAmounts(
  //         sqrtPriceX96Current,
  //         LibTickMath.getSqrtRatioAtTick(tickLower),
  //         LibTickMath.getSqrtRatioAtTick(tickUpper),
  //         0,
  //         amount1Desired
  //       ) != 0
  //     );
  //     console.log(
  //       LibLiquidityAmounts.getLiquidityForAmounts(
  //         sqrtPriceX96Current,
  //         LibTickMath.getSqrtRatioAtTick(tickLower),
  //         LibTickMath.getSqrtRatioAtTick(tickUpper),
  //         0,
  //         amount1Desired
  //       )
  //     );

  //     _testGetPositionValue(
  //       TestGetPositionValueParams({
  //         pool: pancakeV3USDTWBNBPool,
  //         token0Feed: usdtFeed,
  //         token1Feed: wbnbFeed,
  //         tickLower: tickLower,
  //         tickUpper: tickUpper,
  //         amount0Desired: 0,
  //         amount1Desired: amount1Desired
  //       })
  //     );
  //   }

  //   function testForkFuzz_GetPositionValue_BothTokenE18(
  //     uint96 usdtBorrowAmount,
  //     uint96 wbnbBorrowAmount,
  //     uint96 usdtAddLiquidityAmount,
  //     uint96 wbnbAddLiquidityAmount
  //   ) public {
  //     vm.assume(usdtBorrowAmount > 1e18);
  //     vm.assume(wbnbBorrowAmount > 1e18);
  //     vm.assume(usdtAddLiquidityAmount > 1e18);
  //     vm.assume(wbnbAddLiquidityAmount > 1e18);

  //     // Deal tokens
  //     deal(address(wbnb), USER_ALICE, wbnbAddLiquidityAmount);
  //     deal(address(usdt), USER_ALICE, usdtAddLiquidityAmount);

  //     // Setup oracle
  //     vm.startPrank(DEPLOYER);
  //     oracle.setPriceFeedOf(address(usdt), address(usdtFeed));
  //     oracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
  //     oracle.setMaxPriceAge(6_000);
  //     oracle.setMaxPriceDiff(10_500);
  //     vm.stopPrank();

  //     // Add liquidity
  //     vm.startPrank(USER_ALICE);
  //     wbnb.approve(address(pancakeV3PositionManager), type(uint256).max);
  //     usdt.approve(address(pancakeV3PositionManager), type(uint256).max);
  //     (uint256 tokenId,, uint256 amount0, uint256 amount1) = pancakeV3PositionManager.mint(
  //       ICommonV3PositionManager.MintParams({
  //         token0: pancakeV3USDTWBNBPool.token0(),
  //         token1: pancakeV3USDTWBNBPool.token1(),
  //         fee: pancakeV3USDTWBNBPool.fee(),
  //         tickLower: -58000,
  //         tickUpper: -57750,
  //         amount0Desired: usdtAddLiquidityAmount,
  //         amount1Desired: wbnbAddLiquidityAmount,
  //         amount0Min: 0,
  //         amount1Min: 0,
  //         recipient: address(this),
  //         deadline: block.timestamp
  //       })
  //     );
  //     vm.stopPrank();

  //     // Calculate expected value
  //     (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
  //     (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
  //     uint256 expectedPositionValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals())
  //       + amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
  //     uint256 expectedDebtValueUSD = usdtBorrowAmount * uint256(usdtPrice) / (10 ** usdtFeed.decimals())
  //       + wbnbBorrowAmount * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());

  //     // Discard debt > position * 1.1 value
  //     vm.assume(expectedDebtValueUSD * 11 / 10 < expectedPositionValueUSD);

  //     // Mock borrow
  //     vm.mockCall(
  //       mockBank,
  //       abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(usdt)),
  //       abi.encode(0, usdtBorrowAmount)
  //     );
  //     vm.mockCall(
  //       mockBank,
  //       abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(wbnb)),
  //       abi.encode(0, wbnbBorrowAmount)
  //     );

  //     // Mock worker
  //     vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3USDTWBNBPool)));
  //     vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(tokenId));

  //     console.log(expectedPositionValueUSD);
  //     console.log(expectedDebtValueUSD);
  //     assertApproxEqAbs(
  //       oracle.getEquity(mockVaultToken, mockWorker), expectedPositionValueUSD - expectedDebtValueUSD, 1e18
  //     );

  //     // uint256 oracleValueUSD = oracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);

  //     // (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
  //     // uint256 usdtValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals());
  //     // (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
  //     // uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
  //     // uint256 expectedPositionValueUSD = usdtValueUSD + wbnbValueUSD;

  //     // assertApproxEqAbs(oracleValueUSD, expectedPositionValueUSD, 328);

  //     // emit log_named_decimal_uint("amount0 (USDT)", amount0, 18);
  //     // emit log_named_decimal_uint("amount1 (WBNB)", amount1, 18);
  //     // emit log_named_decimal_uint("usdtValue     ", usdtValueUSD, 18);
  //     // emit log_named_decimal_uint("wbnbValue     ", wbnbValueUSD, 18);
  //     // emit log_named_decimal_uint("expectedValue ", expectedPositionValueUSD, 18);
  //     // emit log_named_decimal_uint("oracleValueUSD", oracleValueUSD, 18);
  //     // emit log_named_uint("deltaAbs      ", stdMath.delta(oracleValueUSD, expectedPositionValueUSD));
  //     // emit log_named_decimal_uint("deltaRel      ", stdMath.percentDelta(oracleValueUSD, expectedPositionValueUSD), 16);
  //   }

  //   function testForkFuzz_GetEquity(
  //     int24 tickLower,
  //     int24 tickUpper,
  //     uint160 usdtBorrowAmount,
  //     uint160 wbnbBorrowAmount,
  //     uint160 usdtAddLiquidityAmount,
  //     uint160 wbnbAddLiquidityAmount
  //   ) public {
  //     // Assume valid tick range
  //     // int24 tickSpacing = pancakeV3USDTWBNBPool.tickSpacing();
  //     (, int24 tickCurrent,,,,,) = pancakeV3USDTWBNBPool.slot0();
  //     // bound(tickLower, MIN_TICK, MAX_TICK);
  //     // bound(tickUpper, MIN_TICK, MAX_TICK);
  //     bound(tickLower, tickCurrent - 100000, tickCurrent);
  //     bound(tickUpper, tickCurrent, tickCurrent + 100000);
  //     vm.assume(tickLower < tickUpper);
  //     // vm.assume(tickLower % tickSpacing == 0);
  //     // vm.assume(tickUpper % tickSpacing == 0);

  //     // Deal tokens
  //     deal(address(wbnb), USER_ALICE, wbnbAddLiquidityAmount);
  //     deal(address(usdt), USER_ALICE, usdtAddLiquidityAmount);

  //     // Add liquidity
  //     vm.startPrank(USER_ALICE);
  //     (uint256 tokenId,, uint256 amount0, uint256 amount1) = pancakeV3PositionManager.mint(
  //       ICommonV3PositionManager.MintParams({
  //         token0: pancakeV3USDTWBNBPool.token0(),
  //         token1: pancakeV3USDTWBNBPool.token1(),
  //         fee: pancakeV3USDTWBNBPool.fee(),
  //         tickLower: tickLower,
  //         tickUpper: tickUpper,
  //         amount0Desired: usdtAddLiquidityAmount,
  //         amount1Desired: wbnbAddLiquidityAmount,
  //         amount0Min: 0,
  //         amount1Min: 0,
  //         recipient: address(this),
  //         deadline: block.timestamp
  //       })
  //     );
  //     vm.stopPrank();

  //     // Mock borrow
  //     vm.mockCall(
  //       mockBank,
  //       abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(usdt)),
  //       abi.encode(0, usdtBorrowAmount)
  //     );
  //     vm.mockCall(
  //       mockBank,
  //       abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(wbnb)),
  //       abi.encode(0, wbnbBorrowAmount)
  //     );

  //     // Mock worker
  //     vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3USDTWBNBPool)));
  //     vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(tokenId));

  //     // Calculate expected value
  //     (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
  //     (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
  //     uint256 expectedPositionValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals())
  //       + amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
  //     uint256 expectedDebtValueUSD = usdtBorrowAmount * uint256(usdtPrice) / (10 ** usdtFeed.decimals())
  //       + wbnbBorrowAmount * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());

  //     assertEq(oracle.getEquity(mockVaultToken, mockWorker), expectedPositionValueUSD + expectedDebtValueUSD);
  //   }
}

// TODO: setter tests
// TODO: migrate old CommonOracle test
// function testCorrectness_GetPositionValue_BothTokenE18() public {
//     (uint256 tokenId, uint256 amount0, uint256 amount1) = _mintUSDTWBNB();

//     uint256 oracleValueUSD = liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);

//     (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
//     uint256 usdtValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals());
//     (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
//     uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
//     uint256 expectedPositionValueUSD = usdtValueUSD + wbnbValueUSD;

//     assertApproxEqAbs(oracleValueUSD, expectedPositionValueUSD, 328);

//     if (DEBUG) {
//       emit log_named_decimal_uint("amount0 (USDT)", amount0, 18);
//       emit log_named_decimal_uint("amount1 (WBNB)", amount1, 18);
//       emit log_named_decimal_uint("usdtValue     ", usdtValueUSD, 18);
//       emit log_named_decimal_uint("wbnbValue     ", wbnbValueUSD, 18);
//       emit log_named_decimal_uint("expectedValue ", expectedPositionValueUSD, 18);
//       emit log_named_decimal_uint("oracleValueUSD", oracleValueUSD, 18);
//       emit log_named_uint("deltaAbs      ", stdMath.delta(oracleValueUSD, expectedPositionValueUSD));
//       emit log_named_decimal_uint("deltaRel      ", stdMath.percentDelta(oracleValueUSD, expectedPositionValueUSD), 16);
//     }
//   }

//   function testCorrectness_GetPositionValue_NonE18TokenPool() public {
//     vm.startPrank(ALICE);
//     (uint256 tokenId,, uint256 amount0, uint256 amount1) = pancakeV3PositionManager.mint(
//       ICommonV3PositionManager.MintParams({
//         token0: pancakeV3DOGEWBNBPool.token0(),
//         token1: pancakeV3DOGEWBNBPool.token1(),
//         fee: pancakeV3DOGEWBNBPool.fee(),
//         tickLower: 100000,
//         tickUpper: 200000,
//         amount0Desired: 100e8,
//         amount1Desired: 100 ether,
//         amount0Min: 0,
//         amount1Min: 0,
//         recipient: address(this),
//         deadline: block.timestamp
//       })
//     );
//     vm.stopPrank();

//     uint256 oracleValueUSD = liquidityOracle.getPositionValueUSD(address(pancakeV3DOGEWBNBPool), tokenId);

//     (, int256 dogePrice,,,) = dogeFeed.latestRoundData();
//     uint256 dogeValueUSD = normalizeToE18(amount0, doge.decimals()) * uint256(dogePrice) / (10 ** dogeFeed.decimals());
//     (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
//     uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
//     uint256 expectedPositionValueUSD = dogeValueUSD + wbnbValueUSD;

//     assertApproxEqAbs(oracleValueUSD, expectedPositionValueUSD, 878738326);

//     if (DEBUG) {
//       emit log_named_decimal_uint("amount0 (DOGE)", amount0, 8);
//       emit log_named_decimal_uint("amount1 (WBNB)", amount1, 18);
//       emit log_named_decimal_uint("dogeValue     ", dogeValueUSD, 18);
//       emit log_named_decimal_uint("wbnbValue     ", wbnbValueUSD, 18);
//       emit log_named_decimal_uint("expectedValue ", expectedPositionValueUSD, 18);
//       emit log_named_decimal_uint("oracleValueUSD", oracleValueUSD, 18);
//       emit log_named_uint("deltaAbs      ", stdMath.delta(oracleValueUSD, expectedPositionValueUSD));
//       emit log_named_decimal_uint("deltaRel      ", stdMath.percentDelta(oracleValueUSD, expectedPositionValueUSD), 16);
//     }
//   }

//   function testRevert_GetPositionValue_PriceTooOld_Token0() public {
//     (uint256 tokenId,,) = _mintUSDTWBNB();
//     // Mock price feeds to return updateAt 0
//     uint256 updatedAt = 0;
//     vm.mockCall(
//       address(usdtFeed),
//       abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
//       abi.encode(0, 0, 0, updatedAt, 0)
//     );
//     vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_PriceTooOld.selector);
//     liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
//   }

//   function testRevert_GetPositionValue_PriceTooOld_Token1() public {
//     (uint256 tokenId,,) = _mintUSDTWBNB();
//     // Mock price feeds to return updateAt 0
//     uint256 updatedAt = 0;
//     vm.mockCall(
//       address(wbnbFeed),
//       abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
//       abi.encode(0, 0, 0, updatedAt, 0)
//     );
//     vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_PriceTooOld.selector);
//     liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
//   }

//   function testRevert_GetPositionValue_OraclePriceMoreThanPool_DueToToken0() public {
//     (uint256 tokenId,,) = _mintUSDTWBNB();

//     (, int256 answer,,,) = usdtFeed.latestRoundData();
//     vm.mockCall(
//       address(usdtFeed),
//       abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
//       // increase oracle price of token0 to make oracle price of token0 / token1 higher
//       abi.encode(0, answer * 2, 0, block.timestamp, 0)
//     );
//     vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_OraclePriceTooHigh.selector);
//     liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
//   }

//   function testRevert_GetPositionValue_OraclePriceLessThanPool_DueToToken0() public {
//     (uint256 tokenId,,) = _mintUSDTWBNB();

//     (, int256 answer,,,) = usdtFeed.latestRoundData();
//     vm.mockCall(
//       address(usdtFeed),
//       abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
//       // lower oracle price of token0 to make oracle price of token0 / token1 lower
//       abi.encode(0, answer / 2, 0, block.timestamp, 0)
//     );
//     vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_OraclePriceTooLow.selector);
//     liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
//   }

//   function testRevert_GetPositionValue_OraclePriceMoreThanPool_DueToToken1() public {
//     (uint256 tokenId,,) = _mintUSDTWBNB();

//     (, int256 answer,,,) = wbnbFeed.latestRoundData();
//     vm.mockCall(
//       address(wbnbFeed),
//       abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
//       // lower oracle price of token1 to make oracle price of token0 / token1 higher
//       abi.encode(0, answer / 2, 0, block.timestamp, 0)
//     );
//     vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_OraclePriceTooHigh.selector);
//     liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
//   }

//   function testRevert_GetPositionValue_OraclePriceLessThanPool_DueToToken1() public {
//     (uint256 tokenId,,) = _mintUSDTWBNB();

//     (, int256 answer,,,) = wbnbFeed.latestRoundData();
//     vm.mockCall(
//       address(wbnbFeed),
//       abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
//       // increase oracle price of token1 to make oracle price of token0 / token1 lower
//       abi.encode(0, answer * 2, 0, block.timestamp, 0)
//     );
//     vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_OraclePriceTooLow.selector);
//     liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
//   }
