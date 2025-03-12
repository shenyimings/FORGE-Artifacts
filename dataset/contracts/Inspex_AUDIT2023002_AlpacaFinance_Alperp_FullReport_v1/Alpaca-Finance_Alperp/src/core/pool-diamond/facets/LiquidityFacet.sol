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

import { LibReentrancyGuard } from "../libraries/LibReentrancyGuard.sol";
import { LibPoolV1 } from "../libraries/LibPoolV1.sol";
import { LibPoolConfigV1 } from "../libraries/LibPoolConfigV1.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FarmFacetInterface } from "../interfaces/FarmFacetInterface.sol";
import { GetterFacetInterface } from "../interfaces/GetterFacetInterface.sol";
import { FundingRateFacetInterface } from "../interfaces/FundingRateFacetInterface.sol";
import { LiquidityFacetInterface } from "../interfaces/LiquidityFacetInterface.sol";
import { FlashLoanBorrowerInterface } from "../../../interfaces/FlashLoanBorrowerInterface.sol";
import { StrategyInterface } from "../../../interfaces/StrategyInterface.sol";

contract LiquidityFacet is LiquidityFacetInterface {
  using SafeERC20 for ERC20;
  using SafeCast for uint256;

  error LiquidityFacet_BadAmount();
  error LiquidityFacet_BadAmountOut();
  error LiquidityFacet_BadFlashLoan();
  error LiquidityFacet_BadLength();
  error LiquidityFacet_BadToken();
  error LiquidityFacet_BadTokenIn();
  error LiquidityFacet_BadTokenOut();
  error LiquidityFacet_CoolDown();
  error LiquidityFacet_InsufficientLiquidityMint();
  error LiquidityFacet_LiquidityBuffer();
  error LiquidityFacet_SameTokenInTokenOut();
  error LiquidityFacet_Slippage();
  error LiquidityFacet_SwapDisabled();

  enum LiquidityAction {
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY,
    SWAP
  }

  uint256 internal constant PRICE_PRECISION = 10**30;
  uint256 internal constant BPS = 10000;
  uint256 internal constant USD_DECIMALS = 18;

  event AddLiquidity(
    address account,
    address token,
    uint256 amount,
    uint256 aum,
    uint256 supply,
    uint256 usdDebt,
    uint256 mintAmount
  );
  event CollectSwapFee(
    address user,
    address token,
    uint256 feeUsd,
    uint256 fee
  );
  event CollectAddLiquidityFee(
    address user,
    address token,
    uint256 feeUsd,
    uint256 fee
  );
  event CollectRemoveLiquidityFee(
    address user,
    address token,
    uint256 feeUsd,
    uint256 fee
  );
  event ExitPool(
    address account,
    address token,
    uint256 usdAmount,
    uint256 amountOut,
    uint256 burnFeeBps
  );
  event FlashLoan(
    address borrower,
    address token,
    uint256 amount,
    uint256 fee,
    address receiver
  );
  event JoinPool(
    address account,
    address token,
    uint256 amount,
    uint256 usdDebt,
    uint256 mintFeeBps
  );
  event RemoveLiquidity(
    address account,
    address tokenOut,
    uint256 liquidity,
    uint256 aum,
    uint256 supply,
    uint256 usdDebt,
    uint256 amountOut
  );
  event StrategyDivest(address token, uint256 amount);
  event Swap(
    address account,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    uint256 amountOutAfterFee,
    uint256 swapFeeBps
  );

  function _collectSwapFee(
    address token,
    uint256 tokenPriceUsd,
    uint256 amount,
    uint256 feeBps,
    address account,
    LiquidityAction action
  ) internal returns (uint256) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    uint256 amountAfterFee = (amount * (BPS - feeBps)) / BPS;
    uint256 fee = amount - amountAfterFee;

    poolV1ds.feeReserveOf[token] += fee;
    if (action == LiquidityAction.SWAP) {
      emit CollectSwapFee(
        account,
        token,
        (fee * tokenPriceUsd) / 10**ERC20(token).decimals(),
        fee
      );
    } else if (action == LiquidityAction.ADD_LIQUIDITY) {
      emit CollectAddLiquidityFee(
        account,
        token,
        (fee * tokenPriceUsd) / 10**ERC20(token).decimals(),
        fee
      );
    } else if (action == LiquidityAction.REMOVE_LIQUIDITY) {
      emit CollectRemoveLiquidityFee(
        account,
        token,
        (fee * tokenPriceUsd) / 10**ERC20(token).decimals(),
        fee
      );
    }

    return amountAfterFee;
  }

  modifier allowed(address account) {
    LibPoolV1.allowed(account);
    _;
  }

  modifier nonReentrant() {
    LibReentrancyGuard.lock();
    _;
    LibReentrancyGuard.unlock();
  }

  function addLiquidity(
    address account,
    address token,
    address receiver
  ) external nonReentrant allowed(account) returns (uint256) {
    // LOAD poolV1 diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    // Pull tokens
    uint256 amount = LibPoolV1.pullTokens(token);

    // Check
    if (!LibPoolConfigV1.isAcceptToken(token)) revert LiquidityFacet_BadToken();
    if (amount == 0) revert LiquidityFacet_BadAmount();

    LibPoolV1.realizedFarmPnL(token);

    uint256 aum = GetterFacetInterface(address(this)).getAumE18(true);
    uint256 lpSupply = poolV1ds.alp.totalSupply();

    uint256 usdDebt = _join(
      token,
      amount,
      receiver,
      account,
      LiquidityAction.ADD_LIQUIDITY
    );
    uint256 mintAmount = aum == 0 ? usdDebt : (usdDebt * lpSupply) / aum;

    poolV1ds.alp.mint(receiver, mintAmount);

    emit AddLiquidity(
      account,
      token,
      amount,
      aum,
      lpSupply,
      usdDebt,
      mintAmount
    );

    return mintAmount;
  }

  function _join(
    address token,
    uint256 amount,
    address receiver,
    address account,
    LiquidityAction action
  ) internal returns (uint256) {
    // LOAD diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    FundingRateFacetInterface(address(this)).updateFundingRate(token, token);

    uint256 price = poolV1ds.oracle.getMinPrice(token);

    uint256 tokenValueUsd = (amount * price) / PRICE_PRECISION;
    uint8 tokenDecimals = LibPoolConfigV1.getTokenDecimalsOf(token);
    tokenValueUsd = LibPoolV1.convertTokenDecimals(
      tokenDecimals,
      USD_DECIMALS,
      tokenValueUsd
    );
    if (tokenValueUsd == 0) revert LiquidityFacet_InsufficientLiquidityMint();

    uint256 feeBps = GetterFacetInterface(address(this)).getAddLiquidityFeeBps(
      token,
      tokenValueUsd
    );
    uint256 amountAfterDepositFee = _collectSwapFee(
      token,
      price,
      amount,
      feeBps,
      account,
      action
    );
    uint256 usdDebt = LibPoolV1.convertTokenDecimals(
      tokenDecimals,
      USD_DECIMALS,
      (amountAfterDepositFee * price) / PRICE_PRECISION
    );

    LibPoolV1.increaseUsdDebt(token, usdDebt);
    LibPoolV1.increasePoolLiquidity(token, amountAfterDepositFee);

    poolV1ds.totalUsdDebt += usdDebt;

    emit JoinPool(receiver, token, amount, usdDebt, feeBps);

    return usdDebt;
  }

  function removeLiquidity(
    address account,
    address tokenOut,
    address receiver
  ) external nonReentrant allowed(account) returns (uint256) {
    // LOAD diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    uint256 liquidity = poolV1ds.alp.balanceOf(address(this));

    if (!LibPoolConfigV1.isAcceptToken(tokenOut))
      revert LiquidityFacet_BadToken();
    if (liquidity == 0) revert LiquidityFacet_BadAmount();

    LibPoolV1.realizedFarmPnL(tokenOut);

    uint256 aum = GetterFacetInterface(address(this)).getAumE18(false);
    uint256 lpSupply = poolV1ds.alp.totalSupply();

    uint256 lpUsdValue = (liquidity * aum) / lpSupply;
    // Adjust totalUsdDebt if lpUsdValue > totalUsdDebt.
    if (poolV1ds.totalUsdDebt < lpUsdValue)
      poolV1ds.totalUsdDebt += lpUsdValue - poolV1ds.totalUsdDebt;
    uint256 amountOut = _exit(
      tokenOut,
      lpUsdValue,
      receiver,
      account,
      LiquidityAction.REMOVE_LIQUIDITY
    );

    poolV1ds.alp.burn(address(this), liquidity);
    LibPoolV1.tokenOut(tokenOut, receiver, amountOut);

    emit RemoveLiquidity(
      account,
      tokenOut,
      liquidity,
      aum,
      lpSupply,
      lpUsdValue,
      amountOut
    );

    return amountOut;
  }

  function _exit(
    address token,
    uint256 usdValue,
    address receiver,
    address account,
    LiquidityAction action
  ) internal returns (uint256) {
    // LOAD diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    FundingRateFacetInterface(address(this)).updateFundingRate(token, token);

    uint256 tokenPrice = poolV1ds.oracle.getMaxPrice(token);
    uint256 amountOut = LibPoolV1.convertTokenDecimals(
      18,
      LibPoolConfigV1.getTokenDecimalsOf(token),
      (usdValue * PRICE_PRECISION) / tokenPrice
    );
    if (amountOut == 0) revert LiquidityFacet_BadAmountOut();

    LibPoolV1.decreaseUsdDebt(token, usdValue);
    LibPoolV1.decreasePoolLiquidity(token, amountOut);

    poolV1ds.totalUsdDebt -= usdValue;

    uint256 burnFeeBps = GetterFacetInterface(address(this))
      .getRemoveLiquidityFeeBps(token, usdValue);
    amountOut = _collectSwapFee(
      token,
      poolV1ds.oracle.getMinPrice(token),
      amountOut,
      burnFeeBps,
      account,
      action
    );
    if (amountOut == 0) revert LiquidityFacet_BadAmountOut();

    emit ExitPool(receiver, token, usdValue, amountOut, burnFeeBps);

    return amountOut;
  }

  struct SwapLocalVars {
    uint256 amountIn;
    uint256 priceIn;
    uint256 priceOut;
    uint256 amountOut;
    uint256 usdDebt;
    uint256 swapFeeBps;
    uint256 amountOutAfterFee;
  }

  function swap(
    address account,
    address tokenIn,
    address tokenOut,
    uint256 minAmountOut,
    address receiver
  ) external nonReentrant returns (uint256) {
    SwapLocalVars memory vars;

    // LOAD diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    // Pull Tokens
    uint256 amountIn = LibPoolV1.pullTokens(tokenIn);

    if (!LibPoolConfigV1.isSwapEnable()) revert LiquidityFacet_SwapDisabled();
    if (!LibPoolConfigV1.isAcceptToken(tokenIn))
      revert LiquidityFacet_BadTokenIn();
    if (!LibPoolConfigV1.isAcceptToken(tokenOut))
      revert LiquidityFacet_BadTokenOut();
    if (tokenIn == tokenOut) revert LiquidityFacet_SameTokenInTokenOut();
    if (amountIn == 0) revert LiquidityFacet_BadAmount();

    LibPoolV1.realizedFarmPnL(tokenIn);
    LibPoolV1.realizedFarmPnL(tokenOut);

    FundingRateFacetInterface(address(this)).updateFundingRate(
      tokenIn,
      tokenIn
    );
    FundingRateFacetInterface(address(this)).updateFundingRate(
      tokenOut,
      tokenOut
    );

    vars.priceIn = poolV1ds.oracle.getMinPrice(tokenIn);
    vars.priceOut = poolV1ds.oracle.getMaxPrice(tokenOut);

    vars.amountOut = (amountIn * vars.priceIn) / vars.priceOut;
    vars.amountOut = LibPoolV1.convertTokenDecimals(
      LibPoolConfigV1.getTokenDecimalsOf(tokenIn),
      LibPoolConfigV1.getTokenDecimalsOf(tokenOut),
      vars.amountOut
    );

    // Adjust USD debt as swap shifted the debt between two assets
    vars.usdDebt = (amountIn * vars.priceIn) / PRICE_PRECISION;
    vars.usdDebt = LibPoolV1.convertTokenDecimals(
      LibPoolConfigV1.getTokenDecimalsOf(tokenIn),
      USD_DECIMALS,
      vars.usdDebt
    );

    uint256 swapFeeBps = GetterFacetInterface(address(this)).getSwapFeeBps(
      tokenIn,
      tokenOut,
      vars.usdDebt
    );
    uint256 amountOutAfterFee = _collectSwapFee(
      tokenOut,
      poolV1ds.oracle.getMinPrice(tokenOut),
      vars.amountOut,
      swapFeeBps,
      account,
      LiquidityAction.SWAP
    );

    LibPoolV1.increasePoolLiquidity(tokenIn, amountIn);
    LibPoolV1.increaseUsdDebt(tokenIn, vars.usdDebt);

    LibPoolV1.decreasePoolLiquidity(tokenOut, vars.amountOut);
    LibPoolV1.decreaseUsdDebt(tokenOut, vars.usdDebt);

    // Buffer check
    if (
      poolV1ds.liquidityOf[tokenOut] <
      LibPoolConfigV1.getTokenBufferLiquidityOf(tokenOut)
    ) revert LiquidityFacet_LiquidityBuffer();

    // Slippage check
    if (amountOutAfterFee < minAmountOut) revert LiquidityFacet_Slippage();

    // Transfer amount out.
    LibPoolV1.tokenOut(tokenOut, receiver, amountOutAfterFee);
    emit Swap(
      receiver,
      tokenIn,
      tokenOut,
      amountIn,
      vars.amountOut,
      amountOutAfterFee,
      swapFeeBps
    );

    return amountOutAfterFee;
  }

  struct FlashLoanLocalVars {
    uint256[] totalOfBefore;
    uint256[] fees;
  }

  function flashLoan(
    FlashLoanBorrowerInterface borrower,
    address[] calldata receivers,
    address[] calldata tokens,
    uint256[] calldata amounts,
    bytes calldata data
  ) external nonReentrant {
    if (receivers.length != tokens.length || receivers.length != amounts.length)
      revert LiquidityFacet_BadLength();

    FlashLoanLocalVars memory vars;

    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    vars.totalOfBefore = new uint256[](tokens.length);
    vars.fees = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; ) {
      LibPoolV1.updateTotalOf(tokens[i]);
      vars.totalOfBefore[i] = poolV1ds.totalOf[tokens[i]];
      vars.fees[i] = (amounts[i] * LibPoolConfigV1.flashLoanFeeBps()) / BPS;

      ERC20(tokens[i]).safeTransfer(receivers[i], amounts[i]);

      unchecked {
        ++i;
      }
    }

    borrower.onFlashLoan(msg.sender, tokens, amounts, vars.fees, data);

    for (uint256 i = 0; i < tokens.length; ) {
      LibPoolV1.updateTotalOf(tokens[i]); // must update for make sure that the TotalOf state is not abused
      if (poolV1ds.totalOf[tokens[i]] < vars.totalOfBefore[i] + vars.fees[i])
        revert LiquidityFacet_BadFlashLoan();

      // Collect fee
      poolV1ds.feeReserveOf[tokens[i]] += vars.fees[i];

      emit FlashLoan(
        address(borrower),
        tokens[i],
        amounts[i],
        vars.fees[i],
        receivers[i]
      );

      unchecked {
        ++i;
      }
    }
  }
}
