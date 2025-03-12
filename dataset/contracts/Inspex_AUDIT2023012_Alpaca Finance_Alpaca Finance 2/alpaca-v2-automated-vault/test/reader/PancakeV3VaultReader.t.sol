// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../fixtures/E2EFixture.f.sol";
import { PancakeV3VaultReader, IVaultReader } from "src/reader/PancakeV3VaultReader.sol";
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { LibSqrtPriceX96 } from "src/libraries/LibSqrtPriceX96.sol";
import { LibLiquidityAmounts } from "src/libraries/LibLiquidityAmounts.sol";

contract PancakeV3VaultReaderTest is E2EFixture {
  PancakeV3VaultReader vaultReader;
  uint256 constant MAX_BPS = 10000;

  constructor() E2EFixture() {
    vaultReader = new PancakeV3VaultReader(address(vaultManager), address(bank), address(pancakeV3VaultOracle));
  }

  function _swapExactInput(address tokenIn_, address tokenOut_, uint24 fee_, uint256 swapAmount) internal {
    deal(tokenIn_, address(this), swapAmount);
    // Approve router to spend token1
    IERC20(tokenIn_).approve(address(pancakeV3Router), swapAmount);
    // Swap
    pancakeV3Router.exactInputSingle(
      IPancakeV3Router.ExactInputSingleParams({
        tokenIn: tokenIn_,
        tokenOut: tokenOut_,
        fee: fee_,
        recipient: address(this),
        amountIn: swapAmount,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      })
    );
  }

  function testCorrectness_VaultReader_ShouldWork() external {
    address _token0 = address(usdt);
    address _token1 = address(wbnb);
    address _worker = vaultManager.getWorker(address(vaultToken));
    uint256 depositAmount = 100 ether;

    // Vault action
    {
      // Deposit
      deal(_token0, address(this), depositAmount);
      vm.startPrank(address(this));
      usdt.approve(address(vaultManager), depositAmount);

      AutomatedVaultManager.TokenAmount[] memory deposits = new AutomatedVaultManager.TokenAmount[](1);
      deposits[0] = AutomatedVaultManager.TokenAmount({ token: _token0, amount: depositAmount });
      vaultManager.deposit(address(this), address(vaultToken), deposits, 0);
      vm.stopPrank();

      // Open position with 100 USDT
      bytes[] memory executorData = new bytes[](1);
      executorData[0] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 100 ether, 0));
      vm.prank(MANAGER);
      vaultManager.manage(address(vaultToken), executorData);

      // Borrow 0.3 WBNB and increase position
      deal(_token1, address(moneyMarket), 0.3 ether);
      executorData = new bytes[](2);
      executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (_token1, 0.3 ether));
      executorData[1] = abi.encodeCall(PCSV3Executor01.increasePosition, (0, 0.3 ether));
      vm.prank(MANAGER);
      vaultManager.manage(address(vaultToken), executorData);
    }

    IVaultReader.VaultSummary memory expectedVaultInfo;

    {
      expectedVaultInfo.token0price = pancakeV3VaultOracle.getTokenPrice(_token0);
      expectedVaultInfo.token1price = pancakeV3VaultOracle.getTokenPrice(_token1);
      expectedVaultInfo.token0Undeployed = IERC20(_token0).balanceOf(_worker);
      expectedVaultInfo.token1Undeployed = IERC20(_token1).balanceOf(_worker);
      (, expectedVaultInfo.token0Debt) = bank.getVaultDebt(address(vaultToken), address(_token0));
      (, expectedVaultInfo.token1Debt) = bank.getVaultDebt(address(vaultToken), address(_token1));

      uint256 _tokenId = PancakeV3Worker(_worker).nftTokenId();
      (uint160 _poolSqrtPriceX96,,,,,,) = ICommonV3Pool(PancakeV3Worker(_worker).pool()).slot0();
      (,,,,, int24 _tickLower, int24 _tickUpper, uint128 _liquidity,,,,) =
        PancakeV3Worker(_worker).nftPositionManager().positions(_tokenId);
      (expectedVaultInfo.token0Farmed, expectedVaultInfo.token1Farmed) = LibLiquidityAmounts.getAmountsForLiquidity(
        _poolSqrtPriceX96,
        LibTickMath.getSqrtRatioAtTick(_tickLower),
        LibTickMath.getSqrtRatioAtTick(_tickUpper),
        _liquidity
      );
      expectedVaultInfo.lowerPrice = _tickToPrice(_tickLower, IERC20(_token0).decimals(), IERC20(_token1).decimals());
      expectedVaultInfo.upperPrice = _tickToPrice(_tickUpper, IERC20(_token0).decimals(), IERC20(_token1).decimals());
    }

    IVaultReader.VaultSummary memory vaultSummary = vaultReader.getVaultSummary(address(vaultToken));

    // test all return values work well.
    assertEq(vaultSummary.token0price, expectedVaultInfo.token0price);
    assertEq(vaultSummary.token1price, expectedVaultInfo.token1price);
    assertEq(vaultSummary.token0Undeployed, expectedVaultInfo.token0Undeployed);
    assertEq(vaultSummary.token1Undeployed, expectedVaultInfo.token1Undeployed);
    assertEq(vaultSummary.token0Farmed, expectedVaultInfo.token0Farmed);
    assertEq(vaultSummary.token1Farmed, expectedVaultInfo.token1Farmed);
    assertEq(vaultSummary.token0Debt, expectedVaultInfo.token0Debt);
    assertEq(vaultSummary.token1Debt, expectedVaultInfo.token1Debt);
    assertEq(vaultSummary.lowerPrice, expectedVaultInfo.lowerPrice);
    assertEq(vaultSummary.upperPrice, expectedVaultInfo.upperPrice);
  }

  function _tickToPrice(int24 _tick, uint256 _token0Decimals, uint256 _token1Decimals)
    public
    pure
    returns (uint256 _price)
  {
    // tick => sqrtPriceX96 => price
    uint160 _sqrtPriceX96 = LibTickMath.getSqrtRatioAtTick(_tick);
    _price = LibSqrtPriceX96.decodeSqrtPriceX96(_sqrtPriceX96, _token0Decimals, _token1Decimals);
  }

  function testCorrectness_VaultReader_GetVaultSharePrice() public {
    address _token0 = address(usdt);
    address _token1 = address(wbnb);
    uint256 depositAmount = 100 ether;

    // Vault action
    {
      // Deposit
      deal(_token0, address(this), depositAmount);
      vm.startPrank(address(this));
      usdt.approve(address(vaultManager), depositAmount);

      AutomatedVaultManager.TokenAmount[] memory deposits = new AutomatedVaultManager.TokenAmount[](1);
      deposits[0] = AutomatedVaultManager.TokenAmount({ token: _token0, amount: depositAmount });
      vaultManager.deposit(address(this), address(vaultToken), deposits, 0);
      vm.stopPrank();

      // Open position with 100 USDT
      bytes[] memory executorData = new bytes[](1);
      executorData[0] = abi.encodeCall(PCSV3Executor01.openPosition, (-57870, -57750, 100 ether, 0));
      vm.prank(MANAGER);
      vaultManager.manage(address(vaultToken), executorData);

      // Borrow 0.3 WBNB and increase position
      deal(_token1, address(moneyMarket), 0.3 ether);
      executorData = new bytes[](2);
      executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (_token1, 0.3 ether));
      executorData[1] = abi.encodeCall(PCSV3Executor01.increasePosition, (0, 0.3 ether));
      vm.prank(MANAGER);
      vaultManager.manage(address(vaultToken), executorData);
    }

    // Case 1: Test simple share price, share price with management fee
    (uint256 _sharePrice, uint256 _sharePriceWithManagementFee) = vaultReader.getVaultSharePrice(address(vaultToken));
    // share price should be around 1 since we haven't done anything beside opening position
    assertApproxEqAbs(_sharePrice, 1 ether, 0.005 ether);
    // Share price with management fee should be equal to share price, since we haven't set it yet
    assertEq(_sharePriceWithManagementFee, _sharePrice);

    // Case 2: Test share price, share price with management fee after push position out of range
    _swapExactInput(address(usdt), address(wbnb), 500, 1000000 ether);
    (_sharePrice, _sharePriceWithManagementFee) = vaultReader.getVaultSharePrice(address(vaultToken));
    assertApproxEqAbs(_sharePrice, 1 ether, 0.005 ether);
    assertEq(_sharePriceWithManagementFee, _sharePrice);

    // Case 3: Test share price with management fee after set management fee = 1 token / sec
    // set rate = 1 token/sec
    vm.prank(DEPLOYER);
    vaultManager.setManagementFeePerSec(address(vaultToken), 1);
    // skip
    skip(100);
    (_sharePrice, _sharePriceWithManagementFee) = vaultReader.getVaultSharePrice(address(vaultToken));
    // share => ~1 ether
    assertApproxEqAbs(_sharePrice, 1 ether, 0.005 ether);
    // share with management fee => share price * totalSupply() / (total supply + pending fee)
    assertApproxEqAbs(
      _sharePriceWithManagementFee,
      (_sharePrice * vaultToken.totalSupply())
        / (vaultToken.totalSupply() + vaultManager.pendingManagementFee(address(vaultToken))),
      0.005 ether
    );
  }
}
