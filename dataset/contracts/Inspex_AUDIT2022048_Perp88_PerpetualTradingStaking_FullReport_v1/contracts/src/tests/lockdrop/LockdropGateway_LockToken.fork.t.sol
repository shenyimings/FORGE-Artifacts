// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseTest, console } from "../base/BaseTest.sol";
import { LockdropGateway } from "../../lockdrop/LockdropGateway.sol";
import { MockLockdrop2 } from "../mocks/MockLockdrop2.sol";
import { IStaking } from "../../staking/interfaces/IStaking.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// forge test -vvv --match-contract 'LockdropGateway_LockToken' --fork-url https://rpc.tenderly.co/fork/b9034711-f094-4ffe-9353-86fa37be3381

contract LockdropGateway_LockToken is BaseTest {
  LockdropGateway internal gateway;
  MockLockdrop2 internal daiLockdrop;
  MockLockdrop2 internal usdcLockdrop;
  MockLockdrop2 internal usdtLockdrop;
  MockLockdrop2 internal wbtcLockdrop;
  MockLockdrop2 internal wethLockdrop;
  MockLockdrop2 internal wmaticLockdrop;

  // Tokens
  address internal constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
  address internal constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
  address internal constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
  address internal constant WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
  address internal constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
  address internal constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

  // AToken
  address internal constant amWETH = 0x28424507fefb6f7f8E9D3860F56504E4e5f5f390;
  address internal constant amAAVE = 0x1d2a0E5EC8E5bBDCA5CB219e649B565d8e5c3360;

  // Sushi LP
  address internal constant WETHUSDC =
    0x34965ba0ac2451A34a0471F04CCa3F990b8dea27;
  address internal constant WETHAAVE =
    0x2813D43463C374a680f235c428FB1D7f08dE0B69;

  // Other tokens
  address internal constant crvUSDBTCETH =
    0xdAD97F7713Ae9437fa9249920eC8507e5FbB23d3; // Curve V5 Token
  address internal constant am3Crv = 0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171; // Curve V3 Token (Curve.fi amDAI/amUSDC/amUSDT (am3CRV))

  // Etc.
  address internal constant crvUSDBTCETHZap =
    0x1d8b86e3D88cDb2d34688e87E72F388Cb541B7C8;
  address internal constant sushiRouter =
    0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

  // Wallets
  address internal constant WHALE_1 =
    0xF977814e90dA44bFA03b6295A0616a897441aceC; // holds multiple stable coins
  address internal constant WHALE_2 =
    0x043f8524F87EFb25990b65Ff4918f9128aCF742E; // holds amWETH
  address internal constant WHALE_3 =
    0x975779102B2A82384f872EE759801DB5204CE331; // holds amAAVE
  address internal constant WHALE_CRV =
    0x6c5384bBaE7aF65Ed1b6784213A81DaE18e528b2; // holds crvUSDBTCETH, WETHAAVE
  address internal constant WETHUSDCHolder =
    0x59e3a85A31042b88f3C009efB62936CEB4E760c3;
  address internal constant WETHAAVEHolder =
    0x6c5384bBaE7aF65Ed1b6784213A81DaE18e528b2;

  function setUp() public {
    gateway = deployLockdropGateway(address(0), address(0), address(0), WMATIC);
    daiLockdrop = new MockLockdrop2();
    usdcLockdrop = new MockLockdrop2();
    usdtLockdrop = new MockLockdrop2();
    wbtcLockdrop = new MockLockdrop2();
    wethLockdrop = new MockLockdrop2();
    wmaticLockdrop = new MockLockdrop2();

    // Base token
    gateway.setBaseTokenLockdropInfo(DAI, address(daiLockdrop));
    gateway.setBaseTokenLockdropInfo(USDC, address(usdcLockdrop));
    gateway.setBaseTokenLockdropInfo(USDT, address(usdtLockdrop));
    gateway.setBaseTokenLockdropInfo(WBTC, address(wbtcLockdrop));
    gateway.setBaseTokenLockdropInfo(WETH, address(wethLockdrop));
    gateway.setBaseTokenLockdropInfo(WMATIC, address(wmaticLockdrop));

    // A Token
    gateway.setATokenLockdropInfo(amWETH);
    gateway.setATokenLockdropInfo(amAAVE); // but AAVE does not supported as base token

    // Sushi Lp
    gateway.setLpPairTokenLockdropInfo(WETHUSDC, sushiRouter);
    gateway.setLpPairTokenLockdropInfo(WETHAAVE, sushiRouter); // but AAVE does not supported as base token

    // Curve V3
    gateway.setCurveV3TokenLockdropInfo(am3Crv);
    // Curve V5
    gateway.setCurveV5TokenLockdropInfo(crvUSDBTCETH, crvUSDBTCETHZap, 5);
  }

  function _isExpectedFork() internal view returns (bool) {
    return
      block.number == 32331970 &&
      address(0x5AFA5a3F59DB1BB8a2f55ffDa994AF00a6A02a10).balance ==
      1597507664757010107;
  }

  function testCorrectness_LockBaseToken() external {
    if (!_isExpectedFork()) return;

    vm.startPrank(WHALE_1);

    // Approve
    IERC20(USDC).approve(address(gateway), type(uint256).max);
    IERC20(USDT).approve(address(gateway), type(uint256).max);

    // Whale lock USDC
    gateway.lockToken(address(USDC), 300000000 * 1e6, 30 days); // lockTokenFor
    gateway.lockToken(address(USDC), 10000000 * 1e6, 40 days); // extendLockPeriodFor, addLockAmountFor
    gateway.lockToken(address(USDC), 10000000 * 1e6, 0 days); // addLockAmountFor
    gateway.lockToken(address(USDC), 0, 50 days); // extendLockPeriodFor

    // Assert locked amount/period
    (uint256 lockedAmount, uint256 lockedPeriod, , ) = usdcLockdrop
      .lockdropStates(WHALE_1);
    assertEq(lockedAmount, 320000000 * 1e6);
    assertEq(lockedPeriod, 50 days);

    // Assert call counts
    assertEq(usdcLockdrop.lockTokenForCallCount(), 1);
    assertEq(usdcLockdrop.extendLockPeriodForCallCount(), 2);
    assertEq(usdcLockdrop.addLockAmountForCallCount(), 2);
    vm.stopPrank();
  }

  function testCorrectness_LockBaseToken_Native() external {
    if (!_isExpectedFork()) return;

    vm.deal(WHALE_1, 1 ether);
    vm.startPrank(WHALE_1);

    // Whale lock MATIC
    gateway.lockToken{ value: 1 ether }(address(WMATIC), 1 ether, 30 days); // lockTokenFor

    // Assert locked amount/period
    (uint256 lockedAmount, uint256 lockedPeriod, , ) = wmaticLockdrop
      .lockdropStates(WHALE_1);
    assertEq(lockedAmount, 1 ether);
    assertEq(lockedPeriod, 30 days);

    // Assert call counts
    assertEq(wmaticLockdrop.lockTokenForCallCount(), 1);
    vm.stopPrank();
  }

  function testCorrectness_LockAToken() external {
    if (!_isExpectedFork()) return;

    vm.startPrank(WHALE_2);

    // Approve
    IERC20(amWETH).approve(address(gateway), type(uint256).max);

    // Whale lock amWETH
    gateway.lockToken(address(amWETH), 3000 ether, 30 days);

    // Assert locked amount/period
    (uint256 lockedAmount, uint256 lockedPeriod, , ) = wethLockdrop
      .lockdropStates(WHALE_2);
    assertEq(lockedAmount, 3000 ether);
    assertEq(lockedPeriod, 30 days);

    // Assert call counts
    assertEq(wethLockdrop.lockTokenForCallCount(), 1);
    assertEq(wethLockdrop.extendLockPeriodForCallCount(), 0);
    assertEq(wethLockdrop.addLockAmountForCallCount(), 0);
    vm.stopPrank();
  }

  function testCorrectness_LockLpPairToken() external {
    if (!_isExpectedFork()) return;

    vm.startPrank(WETHUSDCHolder);

    // Approve
    IERC20(WETHUSDC).approve(address(gateway), type(uint256).max);

    // Whale lock WETHUSDC
    gateway.lockToken(address(WETHUSDC), 0.0002 ether, 30 days);

    // Assert locked amount/period
    {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = wethLockdrop
        .lockdropStates(WETHUSDCHolder);
      assertGt(lockedAmount, 0);
      assertEq(lockedPeriod, 30 days);
    }
    {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = usdcLockdrop
        .lockdropStates(WETHUSDCHolder);
      assertGt(lockedAmount, 0);
      assertEq(lockedPeriod, 30 days);
    }

    // Assert call counts
    {
      assertEq(wethLockdrop.lockTokenForCallCount(), 1);
      assertEq(wethLockdrop.extendLockPeriodForCallCount(), 0);
      assertEq(wethLockdrop.addLockAmountForCallCount(), 0);
    }
    {
      assertEq(usdcLockdrop.lockTokenForCallCount(), 1);
      assertEq(usdcLockdrop.extendLockPeriodForCallCount(), 0);
      assertEq(usdcLockdrop.addLockAmountForCallCount(), 0);
    }
    vm.stopPrank();
  }

  function testCorrectness_LockCurveV3Token() external {
    if (!_isExpectedFork()) return;

    // Declarations
    MockLockdrop2[3] memory lockdrops = [
      daiLockdrop,
      usdcLockdrop,
      usdtLockdrop
    ];
    uint256[3] memory lockedAmountBefore;

    vm.startPrank(WHALE_CRV);

    // Approve
    IERC20(am3Crv).approve(address(gateway), type(uint256).max);

    // Lock am3Crv
    gateway.lockToken(address(am3Crv), 20 ether, 30 days); // lockTokenFor

    // Assertion
    for (uint256 i = 0; i < 3; i++) {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = lockdrops[i]
        .lockdropStates(WHALE_CRV);
      assertGt(lockedAmount, lockedAmountBefore[i]);
      assertEq(lockedPeriod, 30 days);
      lockedAmountBefore[i] = lockedAmount;
    }

    // Lock am3Crv again
    gateway.lockToken(address(am3Crv), 50 ether, 36 days); // lockTokenFor

    // Assertion
    for (uint256 i = 0; i < 3; i++) {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = lockdrops[i]
        .lockdropStates(WHALE_CRV);
      assertGt(lockedAmount, lockedAmountBefore[i]);
      assertEq(lockedPeriod, 36 days);
      lockedAmountBefore[i] = lockedAmount;
    }

    // Lock am3Crv again, but with same period
    gateway.lockToken(address(am3Crv), 75 ether, 36 days); // lockTokenFor

    // Assertion
    for (uint256 i = 0; i < 3; i++) {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = lockdrops[i]
        .lockdropStates(WHALE_CRV);
      assertGt(lockedAmount, lockedAmountBefore[i]);
      assertEq(lockedPeriod, 36 days);
      lockedAmountBefore[i] = lockedAmount;
    }

    // Lock am3Crv again, but don't extend period
    gateway.lockToken(address(am3Crv), 1 ether, 0 days); // lockTokenFor

    // Assertion
    for (uint256 i = 0; i < 3; i++) {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = lockdrops[i]
        .lockdropStates(WHALE_CRV);
      assertGt(lockedAmount, lockedAmountBefore[i]);
      assertEq(lockedPeriod, 36 days);
      lockedAmountBefore[i] = lockedAmount;
    }

    // Assert call counts
    for (uint256 i = 0; i < 3; i++) {
      assertEq(lockdrops[i].lockTokenForCallCount(), 1);
      assertEq(lockdrops[i].addLockAmountForCallCount(), 3);
      assertEq(lockdrops[i].extendLockPeriodForCallCount(), 2);
    }
    vm.stopPrank();
  }

  function testCorrectness_LockCurveV5Token() external {
    if (!_isExpectedFork()) return;

    // Declarations
    MockLockdrop2[5] memory lockdrops = [
      daiLockdrop,
      usdcLockdrop,
      usdtLockdrop,
      wbtcLockdrop,
      wethLockdrop
    ];
    uint256[5] memory lockedAmountBefore;

    vm.startPrank(WHALE_CRV);

    // Approve
    IERC20(crvUSDBTCETH).approve(address(gateway), type(uint256).max);

    // Lock crvUSDBTCETH
    gateway.lockToken(address(crvUSDBTCETH), 20 ether, 30 days); // lockTokenFor

    // Assertion
    for (uint256 i = 0; i < 5; i++) {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = lockdrops[i]
        .lockdropStates(WHALE_CRV);
      assertGt(lockedAmount, lockedAmountBefore[i]);
      assertEq(lockedPeriod, 30 days);
      lockedAmountBefore[i] = lockedAmount;
    }

    // Lock crvUSDBTCETH again
    gateway.lockToken(address(crvUSDBTCETH), 50 ether, 36 days); // lockTokenFor

    // Assertion
    for (uint256 i = 0; i < 5; i++) {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = lockdrops[i]
        .lockdropStates(WHALE_CRV);
      assertGt(lockedAmount, lockedAmountBefore[i]);
      assertEq(lockedPeriod, 36 days);
      lockedAmountBefore[i] = lockedAmount;
    }

    // Lock crvUSDBTCETH again, but with same period
    gateway.lockToken(address(crvUSDBTCETH), 75 ether, 36 days); // lockTokenFor

    // Assertion
    for (uint256 i = 0; i < 5; i++) {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = lockdrops[i]
        .lockdropStates(WHALE_CRV);
      assertGt(lockedAmount, lockedAmountBefore[i]);
      assertEq(lockedPeriod, 36 days);
      lockedAmountBefore[i] = lockedAmount;
    }

    // Lock crvUSDBTCETH again, but don't extend period
    gateway.lockToken(address(crvUSDBTCETH), 1 ether, 0 days); // lockTokenFor

    // Assertion
    for (uint256 i = 0; i < 5; i++) {
      (uint256 lockedAmount, uint256 lockedPeriod, , ) = lockdrops[i]
        .lockdropStates(WHALE_CRV);
      assertGt(lockedAmount, lockedAmountBefore[i]);
      assertEq(lockedPeriod, 36 days);
      lockedAmountBefore[i] = lockedAmount;
    }

    // Assert call counts
    for (uint256 i = 0; i < 5; i++) {
      assertEq(lockdrops[i].lockTokenForCallCount(), 1);
      assertEq(lockdrops[i].addLockAmountForCallCount(), 3);
      assertEq(lockdrops[i].extendLockPeriodForCallCount(), 2);
    }
    vm.stopPrank();
  }

  function testRevert_LockTotallyRandomToken() external {
    if (!_isExpectedFork()) return;

    vm.startPrank(WHALE_1);

    vm.expectRevert(
      abi.encodeWithSignature("LockdropGateway_UninitializedToken()")
    );
    gateway.lockToken(address(88), 88 ether, 88 days);
    vm.stopPrank();
  }

  function testRevert_LockAToken_ButWithUnsupportedUnderlyingBaseToken()
    external
  {
    if (!_isExpectedFork()) return;

    vm.startPrank(WHALE_3);

    // Approve
    IERC20(amAAVE).approve(address(gateway), type(uint256).max);

    // Whale lock amAAVE
    // While amAAVE is supported, but AAVE does not, hence revert is expected.
    vm.expectRevert(abi.encodeWithSignature("LockdropGateway_NotBaseToken()"));
    gateway.lockToken(address(amAAVE), 3000 ether, 30 days);
    vm.stopPrank();
  }

  function testRevert_LockLpPairToken_ButWithUnsupportedUnderlyingBaseToken()
    external
  {
    if (!_isExpectedFork()) return;

    vm.startPrank(WETHAAVEHolder);

    // Approve
    IERC20(WETHAAVE).approve(address(gateway), type(uint256).max);

    // A guy lock WETHAAVE
    // While WETHAAVE is supported, but AAVE does not, hence revert is expected.
    vm.expectRevert(abi.encodeWithSignature("LockdropGateway_NotBaseToken()"));
    gateway.lockToken(address(WETHAAVE), 1 ether, 30 days);
    vm.stopPrank();
  }

  function testRevert_LockNonBaseToken_WithZeroAmount() external {
    if (!_isExpectedFork()) return;

    // A Token
    {
      vm.startPrank(WHALE_2);
      // Approve
      IERC20(amWETH).approve(address(gateway), type(uint256).max);
      // Lock amWETH, but with 0 amount
      // Will revert as the amWETH does not allow removeLiquidity 0
      vm.expectRevert(
        abi.encodeWithSignature(
          "LockdropGateway_NonBaseTokenZeroLockedAmount()"
        )
      );
      gateway.lockToken(address(amWETH), 0 ether, 40 days);
      vm.stopPrank();
    }

    // lp pair
    {
      vm.startPrank(WETHUSDCHolder);
      // Approve
      IERC20(WETHUSDC).approve(address(gateway), type(uint256).max);
      // Lock WETHUSDC, but with 0 amount
      // Will revert as the WETHUSDC does not allow removeLiquidity 0
      vm.expectRevert(
        abi.encodeWithSignature(
          "LockdropGateway_NonBaseTokenZeroLockedAmount()"
        )
      );
      gateway.lockToken(address(WETHUSDC), 0 ether, 40 days);
      vm.stopPrank();
    }

    // curveV3
    {
      vm.startPrank(WHALE_CRV);
      // Approve
      IERC20(am3Crv).approve(address(gateway), type(uint256).max);
      // Lock am3Crv, but with 0 amount
      // Will revert as the am3Crv does not allow removeLiquidity 0
      vm.expectRevert(
        abi.encodeWithSignature(
          "LockdropGateway_NonBaseTokenZeroLockedAmount()"
        )
      );
      gateway.lockToken(address(am3Crv), 0 ether, 40 days); // lockTokenFor
      vm.stopPrank();
    }

    // curveV5
    {
      vm.startPrank(WHALE_CRV);
      // Approve
      IERC20(crvUSDBTCETH).approve(address(gateway), type(uint256).max);
      // Lock crvUSDBTCETH, but with 0 amount
      // Will revert as the crvUSDBTCETH does not allow removeLiquidity 0
      vm.expectRevert(
        abi.encodeWithSignature(
          "LockdropGateway_NonBaseTokenZeroLockedAmount()"
        )
      );
      gateway.lockToken(address(crvUSDBTCETH), 0 ether, 40 days); // lockTokenFor
      vm.stopPrank();
    }
  }
}
