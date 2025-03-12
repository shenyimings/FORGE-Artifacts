// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import { IExchangeRateFeeder } from "./ExchangeRateFeeder.sol";
import { IRouter, IConversionRouter } from "../core/Router.sol";
import { Operator } from "../utils/Operator.sol";
import { ISwapper } from "../swapper/ISwapper.sol";
import { IERC20Controlled, ERC20Controlled } from "../utils/ERC20Controlled.sol";
import { UniswapV2Library } from "../libraries/UniswapV2Library.sol";

interface IConversionPool {
  function deposit(uint256 _amount) external;

  function deposit(uint256 _amount, uint256 _minAmountOut) external;

  function redeem(uint256 _amount) external;

  function redeem(uint256 _amount, uint256 _minAmountOut) external;
}

contract ConversionPool is IConversionPool, Context, Operator, Initializable {
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

  function initialize(
    // ===== tokens
    string memory _outputTokenName,
    string memory _outputTokenSymbol,
    address _inputToken,
    address _proxyInputToken,
    address _proxyOutputToken,
    // ===== others
    address _optRouter,
    address _swapper,
    address _exchangeRateFeeder
  ) public initializer {
    inputToken = IERC20(_inputToken);
    outputToken = new ERC20Controlled(_outputTokenName, _outputTokenSymbol);

    proxyInputToken = IERC20(_proxyInputToken);
    proxyOutputToken = IERC20(_proxyOutputToken);

    setRole(msg.sender, msg.sender);
    setSwapper(_swapper);
    setOperationRouter(_optRouter);
    setExchangeRateFeeder(_exchangeRateFeeder);
  }

  // governance

  function setSwapper(address _swapper) public onlyOwner {
    swapper = ISwapper(_swapper);
    inputToken.safeApprove(address(swapper), type(uint256).max);
  }

  function setOperationRouter(address _optRouter) public onlyOwner {
    optRouter = _optRouter;
    proxyInputToken.safeApprove(optRouter, type(uint256).max);
    proxyOutputToken.safeApprove(optRouter, type(uint256).max);
  }

  function setExchangeRateFeeder(address _exchangeRateFeeder) public onlyOwner {
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
    IRouter(optRouter).depositStable(ust);

    uint256 pER = feeder.exchangeRateOf(address(inputToken), false);
    outputToken.mint(_msgSender(), ust.mul(1e18).div(pER));
  }

  function redeem(uint256 _amount) public override _updateExchangeRate {
    require(isRedemptionAllowed, "ConversionPool: redemption not allowed");

    outputToken.burnFrom(_msgSender(), _amount);

    uint256 pER = feeder.exchangeRateOf(address(inputToken), false);
    uint256 out = _amount.mul(pER).div(1e18);

    uint256 aER = feeder.exchangeRateOf(address(proxyInputToken), false);
    IConversionRouter(optRouter).redeemStable(
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
