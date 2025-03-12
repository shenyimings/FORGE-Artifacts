// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { IExchangeRateFeeder } from "./ExchangeRateFeeder.sol";
import { IConversionPool } from "./ConversionPool.sol";
import { IConversionRouterV2 } from "../core/RouterV2.sol";
import { Operator } from "../utils/Operator.sol";
import { ISwapper } from "../swapper/ISwapper.sol";
import { IERC20Controlled, ERC20Controlled } from "../utils/ERC20Controlled.sol";

contract ConversionPoolV2 is IConversionPool, Context, Operator, Initializable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using SafeERC20 for IERC20Controlled;

  // pool token settings
  IERC20 public inputToken; // DAI / USDC / USDT
  IERC20Controlled public outputToken; // aDAI / aUSDC / aUSDT

  // swap settings
  ISwapper public swapper;

  // proxy settings
  IERC20 public proxyInputToken; // UST
  IERC20 public proxyOutputToken; // aUST
  uint256 public proxyReserve = 0; // aUST reserve

  address public optRouter;
  IExchangeRateFeeder public feeder;

  // flags
  bool public isDepositAllowed = true;
  bool public isRedemptionAllowed = true;

  // governance
  function setSwapper(address _swapper) public onlyOwner {
    require(_swapper != address(0x0), "ConversionPoolV2: zero swapper address");
    swapper = ISwapper(_swapper);
    inputToken.safeApprove(address(swapper), type(uint256).max);
  }

  function setOperationRouter(address _optRouter) public onlyOwner {
    require(
      _optRouter != address(0x0),
      "ConversionPoolV2: zero router address"
    );
    optRouter = _optRouter;
    proxyInputToken.safeApprove(optRouter, type(uint256).max);
    proxyOutputToken.safeApprove(optRouter, type(uint256).max);
  }

  function setExchangeRateFeeder(address _exchangeRateFeeder) public onlyOwner {
    require(
      _exchangeRateFeeder != address(0x0),
      "ConversionPoolV2: zero feeder address"
    );
    feeder = IExchangeRateFeeder(_exchangeRateFeeder);
  }

  function setDepositAllowance(bool _allow) public onlyOwner {
    isDepositAllowed = _allow;
  }

  function setRedemptionAllowance(bool _allow) public onlyOwner {
    isRedemptionAllowed = _allow;
  }

  // migrate
  function migrate(address _to) public onlyOwner {
    require(
      _to != address(0x0),
      "ConversionPoolV2: zero migration target address"
    );
    require(
      !(isDepositAllowed && isRedemptionAllowed),
      "ConversionPool: invalid status"
    );

    proxyOutputToken.transfer(_to, proxyOutputToken.balanceOf(address(this)));
  }

  // reserve

  function provideReserve(uint256 _amount) public onlyGranted {
    proxyReserve = proxyReserve.add(_amount);
    proxyOutputToken.safeTransferFrom(_msgSender(), address(this), _amount);
  }

  function removeReserve(uint256 _amount) public onlyGranted {
    proxyReserve = proxyReserve.sub(_amount);
    proxyOutputToken.safeTransfer(_msgSender(), _amount);
  }

  // operations

  modifier _updateExchangeRate {
    feeder.update(address(inputToken));
    feeder.update(address(proxyInputToken));

    _;
  }

  function deductFee(uint256 _amount) internal pure returns (uint256) {
    uint256 base = 1e18;
    uint256 fee = _amount.div(1000);
    if (fee <= base) {
      return _amount.sub(base);
    } else {
      return _amount.sub(fee);
    }
  }

  function earn() public onlyOwner _updateExchangeRate {
    require(
      proxyReserve < proxyOutputToken.balanceOf(address(this)),
      "ConversionPool: not enough balance"
    );

    // UST(aUST) - UST(aToken) = earnable amount
    uint256 pER = feeder.exchangeRateOf(address(inputToken), false);
    uint256 pv = outputToken.totalSupply().mul(pER).div(1e18);

    uint256 aER = feeder.exchangeRateOf(address(proxyInputToken), false);
    uint256 av = proxyOutputToken
    .balanceOf(address(this))
    .sub(proxyReserve)
    .mul(aER)
    .div(1e18);

    if (av < pv) {
      return;
    }

    uint256 earnAmount = av.sub(pv);
    proxyOutputToken.safeTransfer(msg.sender, earnAmount.mul(1e18).div(aER));
  }

  function deposit(uint256 _amount) public override {
    deposit(_amount, 0);
  }

  function deposit(uint256 _amount, uint256 _minAmountOut)
    public
    override
    _updateExchangeRate
  {
    require(isDepositAllowed, "ConversionPool: deposit not stopped");

    inputToken.safeTransferFrom(_msgSender(), address(this), _amount);

    // swap to UST
    swapper.swapToken(
      address(inputToken),
      address(proxyInputToken),
      _amount,
      _minAmountOut,
      address(this)
    );

    // depositStable
    uint256 ust = proxyInputToken.balanceOf(address(this));
    IConversionRouterV2(optRouter).depositStable(ust);

    uint256 pER = feeder.exchangeRateOf(address(inputToken), false);
    uint256 aER = feeder.exchangeRateOf(address(proxyInputToken), false);

    outputToken.mint(
      _msgSender(),
      /* deductFee(ustAmount * (1/aER)) * aER/pER */
      deductFee(ust.mul(1e18).div(aER)).mul(aER).div(pER) // aDAI amount without tax
    );
  }

  function redeem(uint256 _amount) public override _updateExchangeRate {
    require(isRedemptionAllowed, "ConversionPool: redemption not allowed");

    outputToken.burnFrom(_msgSender(), _amount);

    uint256 pER = feeder.exchangeRateOf(address(inputToken), false);
    uint256 out = _amount.mul(pER).div(1e18);

    uint256 aER = feeder.exchangeRateOf(address(proxyInputToken), false);
    IConversionRouterV2(optRouter).redeemStable(
      _msgSender(),
      out.mul(1e18).div(aER),
      address(swapper),
      address(inputToken)
    );
  }

  function redeem(uint256 _amount, uint256 _minAmountOut) public override {
    redeem(_amount);
  }
}
