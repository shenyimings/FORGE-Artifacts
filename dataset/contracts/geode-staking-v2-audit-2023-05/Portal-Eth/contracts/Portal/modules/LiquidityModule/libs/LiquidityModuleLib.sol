// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {PERCENTAGE_DENOMINATOR} from "../../../globals/macros.sol";
// interfaces
import {IgETH} from "../../../interfaces/IgETH.sol";
// libraries
import {AmplificationLib as AL} from "./AmplificationLib.sol";
// contracts
import {ILPToken} from "../../../interfaces/helpers/ILPToken.sol";

/**
 * @title LiquidityModule Library - LML
 *
 * @notice A library to be used within LiquidityModule
 * * Contains functions responsible for custody and AMM functionalities with some changes.
 * * The main functionality of Liquidity Pools is allowing the depositors to have instant access to liquidity
 * * relying on the Oracle Price, with the help of Liquidity Providers.
 *
 * @dev focus point (1-1) of the pricing algorithm is manipulated with PriceIn and PriceOut functions.
 * Because the underlying price of the staked assets are expected to raise in time.
 * One can see this similar to accomplishing a "rebasing" logic, with the help of a trusted price source.
 * Whenever "Effective Balance" is mentioned it refers to the balance projected with the underlying price.
 *
 * @dev Contracts relying on this library must initialize LiquidityModuleLib.Swap struct
 * * Note that this library contains both functions called by users and admins.
 * * Admin functions should be protected within contracts using this library.
 *
 * @author Ice Bear & Crash Bandicoot
 */
library LiquidityModuleLib {
  /**
   * @custom:section                           ** STRUCTS **
   */

  /**
   * @notice Storage struct for the liquidity pool logic, should be correctly initialized.
   *
   * @param gETH ERC1155 contract
   * @param lpToken address of the LP Token
   * @param pooledTokenId gETH ID of the pooled staking derivative
   * @param initialA the amplification coefficient * n * (n - 1)
   * @param futureA the amplification coef that will be effective after futureATime
   * @param initialATime variable around the ramp management of A
   * @param futureATime variable around the ramp management of A
   * @param swapFee fee as a percentage/PERCENTAGE_DENOMINATOR, will be deducted from resulting tokens of a swap
   * @param adminFee fee as a percentage/PERCENTAGE_DENOMINATOR, will be deducted from swapFee
   * @param balances the pool balance as [ETH, gETH]; the contract's actual token balance might differ
   * @param __gap keep the contract size at 16
   */
  struct Swap {
    IgETH gETH;
    ILPToken lpToken;
    uint256 pooledTokenId;
    uint256 initialA;
    uint256 futureA;
    uint256 initialATime;
    uint256 futureATime;
    uint256 swapFee;
    uint256 adminFee;
    uint256[2] balances;
    uint256[5] __gap;
  }

  /**
   * @notice Struct storing variables used in calculations in the
   * calculateWithdrawOneTokenDY function to avoid stack too deep errors
   */
  struct CalculateWithdrawOneTokenDYInfo {
    uint256 d0;
    uint256 d1;
    uint256 newY;
    uint256 feePerToken;
    uint256 preciseA;
  }

  /**
   * @notice  Struct storing variables used in calculations in the
   * {add,remove} Liquidity functions to avoid stack too deep errors
   */
  struct ManageLiquidityInfo {
    ILPToken lpToken;
    uint256 d0;
    uint256 d1;
    uint256 d2;
    uint256 preciseA;
    uint256 totalSupply;
    uint256[2] balances;
  }

  /**
   * @custom:section                           ** CONSTANTS **
   */

  /// @notice Max swap fee is 1% or 100bps of each swap
  uint256 public constant MAX_SWAP_FEE = PERCENTAGE_DENOMINATOR / 100;

  /// @notice Max adminFee is 50% of the swapFee
  /// adminFee does not add additional fee on top of swapFee
  /// instead it takes a certain percentage of the swapFee.
  /// Therefore it has no impact on users but only on the earnings of LPs
  uint256 public constant MAX_ADMIN_FEE = (50 * PERCENTAGE_DENOMINATOR) / 100;

  /// @notice Constant value used as max loop limit
  uint256 private constant MAX_LOOP_LIMIT = 256;

  /**
   * @custom:section                           ** EVENTS **
   */

  event TokenSwap(
    address indexed buyer,
    uint256 tokensSold,
    uint256 tokensBought,
    uint128 soldId,
    uint128 boughtId
  );
  event AddLiquidity(
    address indexed provider,
    uint256[2] tokenAmounts,
    uint256[2] fees,
    uint256 invariant,
    uint256 lpTokenSupply
  );
  event RemoveLiquidity(address indexed provider, uint256[2] tokenAmounts, uint256 lpTokenSupply);
  event RemoveLiquidityOne(
    address indexed provider,
    uint256 lpTokenAmount,
    uint256 lpTokenSupply,
    uint256 boughtId,
    uint256 tokensBought
  );
  event RemoveLiquidityImbalance(
    address indexed provider,
    uint256[2] tokenAmounts,
    uint256[2] fees,
    uint256 invariant,
    uint256 lpTokenSupply
  );
  event NewAdminFee(uint256 newAdminFee);
  event NewSwapFee(uint256 newSwapFee);

  /**
   * @custom:section                           ** HELPERS **
   *
   * @custom:visibility -> pure-internal
   */

  /**
   * @custom:subsection Math helpers
   */

  /**
   * @notice Compares a and b and returns true if the difference between a and b is 1 or 0.
   * @param a uint256 to compare with
   * @param b uint256 to compare with
   * @return True if the difference between a and b is less than 1 or equal.
   */
  function within1(uint256 a, uint256 b) internal pure returns (bool) {
    return (difference(a, b) <= 1);
  }

  /**
   * @notice Calculates absolute difference between a and b
   * @param a uint256 to compare with
   * @param b uint256 to compare with
   * @return Difference between a and b
   */
  function difference(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a > b) {
      return a - b;
    }
    return b - a;
  }

  /**
   * @custom:subsection StableSwap invariants: D,Y,YD
   */

  /**
   * @notice Calculate the price of a token in the pool with given
   *  balances and a particular D.
   *
   * @dev This is accomplished via solving the invariant iteratively.
   * See the StableSwap paper and Curve.fi implementation for further details.
   *
   * x_1**2 + x1 * (sum' - (A*n**n - 1) * D / (A * n**n)) = D ** (n + 1) / (n ** (2 * n) * prod' * A)
   * x_1**2 + b*x_1 = c
   * x_1 = (x_1**2 + c) / (2*x_1 + b)
   *
   * @param a the amplification coefficient * n * (n - 1). See the StableSwap paper for details.
   * @param tokenIndex Index of token we are calculating for.
   * @param xp a  set of pool balances. Array should be
   * the same cardinality as the pool.
   * @param d the stableswap invariant
   * @return the price of the token, in the same precision as in xp
   */
  function getYD(
    uint256 a,
    uint8 tokenIndex,
    uint256[2] memory xp,
    uint256 d
  ) internal pure returns (uint256) {
    uint256 numTokens = 2;
    require(tokenIndex < numTokens, "LML:Token not found");

    uint256 c = d;
    uint256 s;
    uint256 nA = a * numTokens;

    for (uint256 i = 0; i < numTokens; ++i) {
      if (i != tokenIndex) {
        s = s + xp[i];
        c = (c * d) / (xp[i] * (numTokens));
        // If we were to protect the division loss we would have to keep the denominator separate
        // and divide at the end. However this leads to overflow with large numTokens or/and D.
        // c = c * D * D * D * ... overflow!
      }
    }
    c = (c * d * AL.A_PRECISION) / (nA * numTokens);

    uint256 b = s + ((d * AL.A_PRECISION) / nA);
    uint256 yPrev;
    uint256 y = d;

    for (uint256 i = 0; i < MAX_LOOP_LIMIT; ++i) {
      yPrev = y;
      y = ((y * y) + c) / (2 * y + b - d);
      if (within1(y, yPrev)) {
        return y;
      }
    }
    revert("Approximation did not converge");
  }

  /**
   * @notice Get D, the StableSwap invariant, based on a set of balances and a particular A.
   * @param xp a  set of pool balances. Array should be the same cardinality
   * as the pool.
   * @param a the amplification coefficient * n * (n - 1) in A_PRECISION.
   * See the StableSwap paper for details
   * @return the invariant, at the precision of the pool
   */
  function getD(uint256[2] memory xp, uint256 a) internal pure returns (uint256) {
    uint256 numTokens = 2;
    uint256 s = xp[0] + xp[1];
    if (s == 0) {
      return 0;
    }

    uint256 prevD;
    uint256 d = s;
    uint256 nA = a * numTokens;

    for (uint256 i = 0; i < MAX_LOOP_LIMIT; ++i) {
      uint256 dP = (d ** (numTokens + 1)) / (numTokens ** numTokens * xp[0] * xp[1]);
      prevD = d;
      d =
        ((((nA * s) / AL.A_PRECISION) + dP * numTokens) * (d)) /
        (((nA - AL.A_PRECISION) * (d)) / (AL.A_PRECISION) + ((numTokens + 1) * dP));

      if (within1(d, prevD)) {
        return d;
      }
    }

    // Convergence should occur in 4 loops or less. If this is reached, there may be something wrong
    // with the pool. If this were to occur repeatedly, LPs should withdraw via `removeLiquidity()`
    // function which does not rely on D.
    revert("D does not converge");
  }

  /**
   * @notice Calculate the new balances of the tokens given the indexes of the token
   * that is swapped from (FROM) and the token that is swapped to (TO).
   * This function is used as a helper function to calculate how much TO token
   * the user should receive on swap.
   *
   * @param preciseA precise form of amplification coefficient
   * @param tokenIndexFrom index of FROM token
   * @param tokenIndexTo index of TO token
   * @param x the new total amount of FROM token
   * @param xp balances of the tokens in the pool
   * @return the amount of TO token that should remain in the pool
   */
  function getY(
    uint256 preciseA,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 x,
    uint256[2] memory xp
  ) internal pure returns (uint256) {
    uint256 numTokens = 2;
    require(tokenIndexFrom != tokenIndexTo, "LML:Cannot compare token to itself");
    require(tokenIndexFrom < numTokens && tokenIndexTo < numTokens, "LML:Tokens must be in pool");

    uint256 d = getD(xp, preciseA);
    uint256 c = d;
    uint256 s = x;
    uint256 nA = numTokens * (preciseA);

    c = (c * d) / (x * numTokens);
    c = (c * d * (AL.A_PRECISION)) / (nA * numTokens);
    uint256 b = s + ((d * AL.A_PRECISION) / nA);

    uint256 yPrev;
    uint256 y = d;

    for (uint256 i = 0; i < MAX_LOOP_LIMIT; ++i) {
      yPrev = y;
      y = ((y * y) + c) / (2 * y + b - d);
      if (within1(y, yPrev)) {
        return y;
      }
    }
    revert("Approximation did not converge");
  }

  /**
   * @custom:subsection                           ** REBASING FUNCTIONS **
   *
   * @custom:visibility -> view-internal
   */

  /**
   * @notice This function MULTIPLIES the Staking Derivative (gETH) balance with underlying relative price (pricePerShare),
   * to keep pricing around 1-OraclePrice instead of 1-1 like stableSwap pool.
   * @dev this function assumes prices are sent with the indexes that [ETH, gETH]
   * @param balance balance that will be taken into calculation
   * @param i if i is 0 it means we are dealing with ETH, if i is 1 it is gETH
   */
  function _pricedIn(
    Swap storage self,
    uint256 balance,
    uint256 i
  ) internal view returns (uint256) {
    return
      i == 1
        ? (balance * self.gETH.pricePerShare(self.pooledTokenId)) / self.gETH.denominator()
        : balance;
  }

  /**
   * @notice This function DIVIDES the Staking Derivative (gETH) balance with underlying relative price (pricePerShare),
   * to keep pricing around 1-OraclePrice instead of 1-1 like stableSwap pool.
   * @dev this function assumes prices are sent with the indexes that [ETH, gETH]
   * @param balance balance that will be taken into calculation
   * @param i if i is 0 it means we are dealing with ETH, if i is 1 it is gETH
   */
  function _pricedOut(
    Swap storage self,
    uint256 balance,
    uint256 i
  ) internal view returns (uint256) {
    return
      i == 1
        ? (balance * self.gETH.denominator()) / self.gETH.pricePerShare(self.pooledTokenId)
        : balance;
  }

  /**
   * @notice This function MULTIPLIES the Staking Derivative (gETH) balance with underlying relative price (pricePerShare),
   * to keep pricing around 1-OraclePrice instead of 1-1 like stableSwap pool.
   * @dev this function assumes prices are sent with the indexes that [ETH, gETH]
   * @param balances ARRAY of balances that will be taken into calculation
   */
  function _pricedInBatch(
    Swap storage self,
    uint256[2] memory balances
  ) internal view returns (uint256[2] memory _p) {
    _p[0] = balances[0];
    _p[1] = (balances[1] * self.gETH.pricePerShare(self.pooledTokenId)) / self.gETH.denominator();
    return _p;
  }

  /**
   * @notice This function DIVIDES the Staking Derivative (gETH) balance with underlying relative price (pricePerShare),
   * to keep pricing around 1-OraclePrice instead of 1-1 like stableSwap pool.
   * @dev this function assumes prices are sent with the indexes that [ETH, gETH]
   * @param balances ARRAY of balances that will be taken into calculation
   */
  function _pricedOutBatch(
    Swap storage self,
    uint256[2] memory balances
  ) internal view returns (uint256[2] memory _p) {
    _p[0] = balances[0];
    _p[1] = (balances[1] * self.gETH.denominator()) / self.gETH.pricePerShare(self.pooledTokenId);
    return _p;
  }

  /**
   * @custom:subsection                           ** DEBT FUNCTIONS **
   *
   * @custom:visibility -> view
   *
   * @dev debt refers to the amount of ETH needed to stabilize the pool
   */

  /**
   * @custom:visibility -> internal
   */
  /**
   * @notice Get Debt, The amount of buyback for stable pricing.
   * @param xp a  set of pool balances. Array should be the same cardinality
   * as the pool.
   * @param a the amplification coefficient * n * (n - 1) in A_PRECISION.
   * See the StableSwap paper for details
   * @return debt the half of the D StableSwap invariant when debt is needed to be payed.
   */
  function _getDebt(
    Swap storage self,
    uint256[2] memory xp,
    uint256 a
  ) internal view returns (uint256 debt) {
    uint256 halfD = getD(xp, a) / 2;
    if (xp[0] >= halfD) {
      debt = 0;
    } else {
      uint256 dy = xp[1] - halfD;
      uint256 feeHalf = (dy * self.swapFee) / PERCENTAGE_DENOMINATOR / 2;
      debt = halfD - xp[0] + feeHalf;
    }
  }

  /**
   * @custom:visibility -> external
   */
  /**
   * @return debt the half of the D StableSwap invariant when debt is needed to be payed.
   * @dev might change when price is in.
   */
  function getDebt(Swap storage self) external view returns (uint256) {
    return _getDebt(self, _pricedInBatch(self, self.balances), AL._getAPrecise(self));
  }

  /**
   * @custom:section                           ** SWAP HELPER FUNCTIONS **
   */

  /**
   * @custom:visibility -> pure-internal
   */
  /**
   * @notice A simple method to calculate amount of each underlying
   * tokens that is returned upon burning given amount of
   * LP tokens
   *
   * @param amount the amount of LP tokens that would to be burned on
   * withdrawal
   * @return amounts of tokens user will receive as an array [ETH, gETH]
   */
  function _calculateRemoveLiquidity(
    uint256[2] memory balances,
    uint256 amount,
    uint256 totalSupply
  ) internal pure returns (uint256[2] memory amounts) {
    require(amount <= totalSupply, "LML:Cannot exceed total supply");

    amounts[0] = (balances[0] * amount) / totalSupply;
    amounts[1] = (balances[1] * amount) / totalSupply;

    return amounts;
  }

  /**
   * @custom:visibility -> view-internal
   */

  function _calculateWithdrawOneToken(
    Swap storage self,
    uint256 tokenAmount,
    uint8 tokenIndex,
    uint256 totalSupply
  ) internal view returns (uint256, uint256) {
    uint256 dy;
    uint256 newY;
    uint256 currentY;

    (dy, newY, currentY) = calculateWithdrawOneTokenDY(self, tokenIndex, tokenAmount, totalSupply);

    uint256 dySwapFee = currentY - newY - dy;

    return (dy, dySwapFee);
  }

  /**
   * @notice Internally calculates a swap between two tokens.
   *
   * @dev The caller is expected to transfer the actual amounts (dx and dy)
   * using the token contracts.
   *
   * @param self Swap struct to read from
   * @param tokenIndexFrom the token to sell
   * @param tokenIndexTo the token to buy
   * @param dx the number of tokens to sell. If the token charges a fee on transfers,
   * use the amount that gets transferred after the fee.
   * @return dy the number of tokens the user will get
   * @return dyFee the associated fee
   */
  function _calculateSwap(
    Swap storage self,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256[2] memory balances
  ) internal view returns (uint256 dy, uint256 dyFee) {
    require(tokenIndexFrom < 2 && tokenIndexTo < 2, "LML:Token index out of range");

    uint256 x = _pricedIn(self, dx + balances[tokenIndexFrom], tokenIndexFrom);
    uint256[2] memory pricedBalances = _pricedInBatch(self, balances);
    uint256 y = _pricedOut(
      self,
      getY(AL._getAPrecise(self), tokenIndexFrom, tokenIndexTo, x, pricedBalances),
      tokenIndexTo // => not id, index !!!
    );
    dy = balances[tokenIndexTo] - y - 1;
    dyFee = (dy * self.swapFee) / (PERCENTAGE_DENOMINATOR);
    dy = dy - dyFee;
  }

  /**
   * @custom:visibility -> view-external
   */

  /**
   * @notice Calculate the dy, the amount of selected token that user receives and
   * the fee of withdrawing in one token
   * @param tokenAmount the amount to withdraw in the pool's precision
   * @param tokenIndex which token will be withdrawn
   * @param self Swap struct to read from
   * @return the amount of token user will receive
   */
  function calculateWithdrawOneToken(
    Swap storage self,
    uint256 tokenAmount,
    uint8 tokenIndex
  ) external view returns (uint256) {
    (uint256 availableTokenAmount, ) = _calculateWithdrawOneToken(
      self,
      tokenAmount,
      tokenIndex,
      self.lpToken.totalSupply()
    );
    return availableTokenAmount;
  }

  /**
   * @notice Calculate the dy of withdrawing in one token
   * @param self Swap struct to read from
   * @param tokenIndex which token will be withdrawn
   * @param tokenAmount the amount to withdraw in the pools precision
   * @return the d and the new y after withdrawing one token
   */
  function calculateWithdrawOneTokenDY(
    Swap storage self,
    uint8 tokenIndex,
    uint256 tokenAmount,
    uint256 totalSupply
  ) internal view returns (uint256, uint256, uint256) {
    // Get the current D, then solve the stableswap invariant
    // y_i for D - tokenAmount

    require(tokenIndex < 2, "LML:Token index out of range");

    CalculateWithdrawOneTokenDYInfo memory v = CalculateWithdrawOneTokenDYInfo(0, 0, 0, 0, 0);
    v.preciseA = AL._getAPrecise(self);
    v.d0 = getD(_pricedInBatch(self, self.balances), v.preciseA);
    v.d1 = v.d0 - ((tokenAmount * v.d0) / totalSupply);

    require(tokenAmount <= self.balances[tokenIndex], "LML:Withdraw exceeds available");

    v.newY = _pricedOut(
      self,
      getYD(v.preciseA, tokenIndex, _pricedInBatch(self, self.balances), v.d1),
      tokenIndex
    );

    uint256[2] memory xpReduced;

    v.feePerToken = self.swapFee / 2;
    for (uint256 i = 0; i < 2; ++i) {
      uint256 xpi = self.balances[i];
      xpReduced[i] =
        xpi -
        ((((i == tokenIndex) ? (xpi * v.d1) / v.d0 - v.newY : xpi - ((xpi * v.d1) / (v.d0))) *
          (v.feePerToken)) / (PERCENTAGE_DENOMINATOR));
    }

    uint256 dy = xpReduced[tokenIndex] -
      _pricedOut(
        self,
        (getYD(v.preciseA, tokenIndex, _pricedInBatch(self, xpReduced), v.d1)),
        tokenIndex
      );
    dy = dy - 1;

    return (dy, v.newY, self.balances[tokenIndex]);
  }

  /**
   * @notice Get the virtual price, to help calculate profit
   * @param self Swap struct to read from
   * @return the virtual price
   */
  function getVirtualPrice(Swap storage self) external view returns (uint256) {
    uint256 d = getD(_pricedInBatch(self, self.balances), AL._getAPrecise(self));
    ILPToken lpToken = self.lpToken;
    uint256 supply = lpToken.totalSupply();
    if (supply > 0) {
      return (d * 10 ** 18) / supply;
    }
    return 0;
  }

  /**
   * @notice Externally calculates a swap between two tokens.
   * @param self Swap struct to read from
   * @param tokenIndexFrom the token to sell
   * @param tokenIndexTo the token to buy
   * @param dx the number of tokens to sell. If the token charges a fee on transfers,
   * use the amount that gets transferred after the fee.
   * @return dy the number of tokens the user will get
   */
  function calculateSwap(
    Swap storage self,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx
  ) external view returns (uint256 dy) {
    (dy, ) = _calculateSwap(self, tokenIndexFrom, tokenIndexTo, dx, self.balances);
  }

  /**
   * @notice Uses _calculateRemoveLiquidity with Effective Balances,
   * then projects the prices to the token amounts
   * to get Real Balances, before removing them from pool.
   */
  function calculateRemoveLiquidity(
    Swap storage self,
    uint256 amount
  ) external view returns (uint256[2] memory) {
    return
      _pricedOutBatch(
        self,
        _calculateRemoveLiquidity(
          _pricedInBatch(self, self.balances),
          amount,
          self.lpToken.totalSupply()
        )
      );
  }

  /**
   * @notice A simple method to calculate prices from deposits or
   * withdrawals, excluding fees but including slippage. This is
   * helpful as an input into the various "min" parameters on calls
   * to fight front-running
   *
   * @dev This shouldn't be used outside frontends for user estimates.
   *
   * @param self Swap struct to read from
   * @param amounts an array of token amounts to deposit or withdrawal,
   * corresponding to pooledTokens. The amount should be in each
   * pooled token's native precision. If a token charges a fee on transfers,
   * use the amount that gets transferred after the fee.
   * @param deposit whether this is a deposit or a withdrawal
   * @return if deposit was true, total amount of lp token that will be minted and if
   * deposit was false, total amount of lp token that will be burned
   */
  function calculateTokenAmount(
    Swap storage self,
    uint256[2] calldata amounts,
    bool deposit
  ) external view returns (uint256) {
    uint256 a = AL._getAPrecise(self);
    uint256[2] memory balances = self.balances;

    uint256 d0 = getD(_pricedInBatch(self, balances), a);
    for (uint256 i = 0; i < 2; ++i) {
      if (deposit) {
        balances[i] = balances[i] + amounts[i];
      } else {
        require(amounts[i] <= balances[i], "LML:Cannot withdraw > available");
        balances[i] = balances[i] - amounts[i];
      }
    }
    uint256 d1 = getD(_pricedInBatch(self, balances), a);
    uint256 totalSupply = self.lpToken.totalSupply();

    if (deposit) {
      return ((d1 - d0) * totalSupply) / d0;
    } else {
      return ((d0 - d1) * totalSupply) / d0;
    }
  }

  /**
   * @custom:section                           ** ADMIN HELPER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */

  /**
   * @notice return accumulated amount of admin fees of the token with given index
   * @param self Swap struct to read from
   * @param index Index of the pooled token
   * @return admin balance in the token's precision
   */
  function getAdminBalance(Swap storage self, uint256 index) external view returns (uint256) {
    require(index < 2, "LML:Token index out of range");
    if (index == 0) {
      return address(this).balance - (self.balances[index]);
    } else if (index == 1) {
      return self.gETH.balanceOf(address(this), self.pooledTokenId) - (self.balances[index]);
    } else {
      revert();
    }
  }

  /**
   * @custom:section                           ** STATE MODIFYING FUNCTIONS **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice swap two tokens in the pool
   * @param self Swap struct to read from and write to
   * @param tokenIndexFrom the token the user wants to sell
   * @param tokenIndexTo the token the user wants to buy
   * @param dx the amount of tokens the user wants to sell
   * @param minDy the min amount the user would like to receive, or revert.
   * @return amount of token user received on swap
   */
  function swap(
    Swap storage self,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy
  ) external returns (uint256) {
    IgETH gETHRef = self.gETH;
    if (tokenIndexFrom == 0) {
      // Means user is selling some ETH to the pool to get some gETH.
      // In which case, we need to send exactly that amount of ETH.
      require(dx == msg.value, "LML:Cannot swap != eth sent");
    }
    if (tokenIndexFrom == 1) {
      // Means user is selling some gETH to the pool to get some ETH.

      require(dx <= gETHRef.balanceOf(msg.sender, self.pooledTokenId), "LML:Cannot swap > you own");

      // Transfer tokens first
      uint256 beforeBalance = gETHRef.balanceOf(address(this), self.pooledTokenId);
      gETHRef.safeTransferFrom(msg.sender, address(this), self.pooledTokenId, dx, "");

      // Use the actual transferred amount for AMM math
      dx = gETHRef.balanceOf(address(this), self.pooledTokenId) - beforeBalance;
    }

    uint256 dy;
    uint256 dyFee;
    // Meaning the real balances *without* any effect of underlying price
    // However, when we call _calculateSwap, it uses pricedIn function before calculation,
    // and pricedOut function after the calculation. So, we don't need to use priceOut here.
    uint256[2] memory balances = self.balances;
    (dy, dyFee) = _calculateSwap(self, tokenIndexFrom, tokenIndexTo, dx, balances);

    require(dy >= minDy, "LML:Swap didnot result in min tokens");
    uint256 dyAdminFee = (dyFee * self.adminFee) / PERCENTAGE_DENOMINATOR;

    // To prevent any Reentrancy, balances are updated before transfering the tokens.
    self.balances[tokenIndexFrom] = balances[tokenIndexFrom] + dx;
    self.balances[tokenIndexTo] = balances[tokenIndexTo] - dy - dyAdminFee;

    if (tokenIndexTo == 0) {
      // Means contract is going to send Idle Ether (ETH)
      (bool sent, ) = payable(msg.sender).call{value: dy}("");
      require(sent, "LML:Failed to send Ether");
    }
    if (tokenIndexTo == 1) {
      // Means contract is going to send staked ETH (gETH)
      gETHRef.safeTransferFrom(address(this), msg.sender, self.pooledTokenId, dy, "");
    }

    emit TokenSwap(msg.sender, dx, dy, tokenIndexFrom, tokenIndexTo);

    return dy;
  }

  /**
   * @notice Add liquidity to the pool
   * @param self Swap struct to read from and write to
   * @param amounts the amounts of each token to add, in their native precision
   * @param minToMint the minimum LP tokens adding this amount of liquidity
   * should mint, otherwise revert. Handy for front-running mitigation
   * allowed addresses. If the pool is not in the guarded launch phase, this parameter will be ignored.
   * @return amount of LP token user received
   */
  function addLiquidity(
    Swap storage self,
    uint256[2] memory amounts,
    uint256 minToMint
  ) external returns (uint256) {
    require(amounts[0] == msg.value, "LML:received less or more ETH than expected");
    IgETH gETHRef = self.gETH;
    // current state
    ManageLiquidityInfo memory v = ManageLiquidityInfo(
      self.lpToken,
      0,
      0,
      0,
      AL._getAPrecise(self),
      0,
      self.balances
    );
    v.totalSupply = v.lpToken.totalSupply();
    if (v.totalSupply != 0) {
      v.d0 = getD(_pricedInBatch(self, v.balances), v.preciseA);
    }

    uint256[2] memory newBalances;
    newBalances[0] = v.balances[0] + msg.value;

    for (uint256 i = 0; i < 2; ++i) {
      require(v.totalSupply != 0 || amounts[i] > 0, "LML:Must supply all tokens in pool");
    }

    {
      // Transfer tokens first
      uint256 beforeBalance = gETHRef.balanceOf(address(this), self.pooledTokenId);
      gETHRef.safeTransferFrom(msg.sender, address(this), self.pooledTokenId, amounts[1], "");

      // Update the amounts[] with actual transfer amount
      amounts[1] = gETHRef.balanceOf(address(this), self.pooledTokenId) - beforeBalance;

      newBalances[1] = v.balances[1] + amounts[1];
    }

    // invariant after change
    v.d1 = getD(_pricedInBatch(self, newBalances), v.preciseA);
    require(v.d1 > v.d0, "LML:D should increase");

    // updated to reflect fees and calculate the user's LP tokens
    v.d2 = v.d1;
    uint256[2] memory fees;

    if (v.totalSupply != 0) {
      uint256 feePerToken = self.swapFee / 2;
      for (uint256 i = 0; i < 2; ++i) {
        uint256 idealBalance = (v.d1 * v.balances[i]) / v.d0;
        fees[i] =
          (feePerToken * (difference(idealBalance, newBalances[i]))) /
          (PERCENTAGE_DENOMINATOR);
        self.balances[i] =
          newBalances[i] -
          ((fees[i] * (self.adminFee)) / (PERCENTAGE_DENOMINATOR));
        newBalances[i] = newBalances[i] - (fees[i]);
      }
      v.d2 = getD(_pricedInBatch(self, newBalances), v.preciseA);
    } else {
      // the initial depositor doesn't pay fees
      self.balances = newBalances;
    }

    uint256 toMint;
    if (v.totalSupply == 0) {
      toMint = v.d1;
    } else {
      toMint = ((v.d2 - v.d0) * v.totalSupply) / v.d0;
    }

    require(toMint >= minToMint, "LML:Could not mint min requested");
    // mint the user's LP tokens
    v.lpToken.mint(msg.sender, toMint);

    emit AddLiquidity(msg.sender, amounts, fees, v.d1, v.totalSupply + toMint);
    return toMint;
  }

  /**
   * @notice Burn LP tokens to remove liquidity from the pool.
   * @dev Liquidity can always be removed, even when the pool is paused.
   * @param self Swap struct to read from and write to
   * @param amount the amount of LP tokens to burn
   * @param minAmounts the minimum amounts of each token in the pool
   * acceptable for this burn. Useful as a front-running mitigation
   * @return amounts of tokens the user received
   */
  function removeLiquidity(
    Swap storage self,
    uint256 amount,
    uint256[2] calldata minAmounts
  ) external returns (uint256[2] memory) {
    ILPToken lpToken = self.lpToken;
    IgETH gETHRef = self.gETH;
    require(amount <= lpToken.balanceOf(msg.sender), "LML:>LP.balanceOf");

    uint256[2] memory balances = self.balances;
    uint256 totalSupply = lpToken.totalSupply();

    uint256[2] memory amounts = _pricedOutBatch(
      self,
      _calculateRemoveLiquidity(_pricedInBatch(self, balances), amount, totalSupply)
    );

    for (uint256 i = 0; i < amounts.length; ++i) {
      require(amounts[i] >= minAmounts[i], "LML:amounts[i] < minAmounts[i]");
      self.balances[i] = balances[i] - amounts[i];
    }

    // To prevent any Reentrancy, LP tokens are burned before transfering the tokens.
    lpToken.burnFrom(msg.sender, amount);

    (bool sent, ) = payable(msg.sender).call{value: amounts[0]}("");
    require(sent, "LML:Failed to send Ether");

    gETHRef.safeTransferFrom(address(this), msg.sender, self.pooledTokenId, amounts[1], "");

    emit RemoveLiquidity(msg.sender, amounts, totalSupply - amount);
    return amounts;
  }

  /**
   * @notice Remove liquidity from the pool all in one token.
   * @param self Swap struct to read from and write to
   * @param tokenAmount the amount of the lp tokens to burn
   * @param tokenIndex the index of the token you want to receive
   * @param minAmount the minimum amount to withdraw, otherwise revert
   * @return amount chosen token that user received
   */
  function removeLiquidityOneToken(
    Swap storage self,
    uint256 tokenAmount,
    uint8 tokenIndex,
    uint256 minAmount
  ) external returns (uint256) {
    ILPToken lpToken = self.lpToken;
    IgETH gETHRef = self.gETH;

    require(tokenAmount <= lpToken.balanceOf(msg.sender), "LML:>LP.balanceOf");
    require(tokenIndex < 2, "LML:Token not found");

    uint256 totalSupply = lpToken.totalSupply();

    (uint256 dy, uint256 dyFee) = _calculateWithdrawOneToken(
      self,
      tokenAmount,
      tokenIndex,
      totalSupply
    );

    require(dy >= minAmount, "LML:dy < minAmount");

    // To prevent any Reentrancy, LP tokens are burned before transfering the tokens.
    self.balances[tokenIndex] =
      self.balances[tokenIndex] -
      (dy + ((dyFee * (self.adminFee)) / (PERCENTAGE_DENOMINATOR)));
    lpToken.burnFrom(msg.sender, tokenAmount);

    if (tokenIndex == 0) {
      (bool sent, ) = payable(msg.sender).call{value: dy}("");
      require(sent, "LML:Failed to send Ether");
    }
    if (tokenIndex == 1) {
      gETHRef.safeTransferFrom(address(this), msg.sender, self.pooledTokenId, dy, "");
    }

    emit RemoveLiquidityOne(msg.sender, tokenAmount, totalSupply, tokenIndex, dy);

    return dy;
  }

  /**
   * @notice Remove liquidity from the pool, weighted differently than the
   * pool's current balances.
   *
   * @param self Swap struct to read from and write to
   * @param amounts how much of each token to withdraw
   * @param maxBurnAmount the max LP token provider is willing to pay to
   * remove liquidity. Useful as a front-running mitigation.
   * @return actual amount of LP tokens burned in the withdrawal
   */
  function removeLiquidityImbalance(
    Swap storage self,
    uint256[2] memory amounts,
    uint256 maxBurnAmount
  ) public returns (uint256) {
    IgETH gETHRef = self.gETH;

    ManageLiquidityInfo memory v = ManageLiquidityInfo(
      self.lpToken,
      0,
      0,
      0,
      AL._getAPrecise(self),
      0,
      self.balances
    );
    v.totalSupply = v.lpToken.totalSupply();

    require(
      maxBurnAmount <= v.lpToken.balanceOf(msg.sender) && maxBurnAmount != 0,
      "LML:>LP.balanceOf"
    );

    uint256 feePerToken = self.swapFee / 2;
    uint256[2] memory fees;

    {
      uint256[2] memory balances1;

      v.d0 = getD(_pricedInBatch(self, v.balances), v.preciseA);
      for (uint256 i = 0; i < 2; ++i) {
        require(amounts[i] <= v.balances[i], "LML:Cannot withdraw > available");
        balances1[i] = v.balances[i] - amounts[i];
      }
      v.d1 = getD(_pricedInBatch(self, balances1), v.preciseA);

      for (uint256 i = 0; i < 2; ++i) {
        uint256 idealBalance = (v.d1 * v.balances[i]) / v.d0;
        uint256 _diff = difference(idealBalance, balances1[i]);
        fees[i] = (feePerToken * _diff) / PERCENTAGE_DENOMINATOR;
        uint256 adminFee = self.adminFee;
        {
          self.balances[i] = balances1[i] - ((fees[i] * adminFee) / PERCENTAGE_DENOMINATOR);
        }
        balances1[i] = balances1[i] - fees[i];
      }

      v.d2 = getD(_pricedInBatch(self, balances1), v.preciseA);
    }

    uint256 tokenAmount = ((v.d0 - v.d2) * (v.totalSupply)) / v.d0;
    require(tokenAmount != 0, "LML:Burnt amount cannot be zero");
    tokenAmount = tokenAmount + 1;

    require(tokenAmount <= maxBurnAmount, "LML:tokenAmount > maxBurnAmount");

    // To prevent any Reentrancy, LP tokens are burned before transfering the tokens.
    v.lpToken.burnFrom(msg.sender, tokenAmount);

    (bool sent, ) = payable(msg.sender).call{value: amounts[0]}("");
    require(sent, "LML:Failed to send Ether");

    gETHRef.safeTransferFrom(address(this), msg.sender, self.pooledTokenId, amounts[1], "");

    emit RemoveLiquidityImbalance(msg.sender, amounts, fees, v.d1, v.totalSupply - tokenAmount);

    return tokenAmount;
  }

  /**
   * @custom:subsection                           ** ADMIN FUNCTIONS **
   */

  /**
   * @notice withdraw all admin fees to a given address
   * @param self Swap struct to withdraw fees from
   * @param receiver Address to send the fees to
   */
  function withdrawAdminFees(Swap storage self, address receiver) external {
    IgETH gETHRef = self.gETH;
    uint256 tokenBalance = gETHRef.balanceOf(address(this), self.pooledTokenId) - self.balances[1];
    if (tokenBalance != 0) {
      gETHRef.safeTransferFrom(address(this), receiver, self.pooledTokenId, tokenBalance, "");
    }

    uint256 etherBalance = address(this).balance - self.balances[0];
    if (etherBalance != 0) {
      (bool sent, ) = payable(receiver).call{value: etherBalance}("");
      require(sent, "LML:Failed to send Ether");
    }
  }

  /**
   * @notice Sets the admin fee
   * @dev adminFee cannot be higher than 100% of the swap fee
   * @param self Swap struct to update
   * @param newAdminFee new admin fee to be applied on future transactions
   */
  function setAdminFee(Swap storage self, uint256 newAdminFee) external {
    require(newAdminFee <= MAX_ADMIN_FEE, "LML:Fee is too high");
    self.adminFee = newAdminFee;

    emit NewAdminFee(newAdminFee);
  }

  /**
   * @notice update the swap fee
   * @dev fee cannot be higher than 1% of each swap
   * @param self Swap struct to update
   * @param newSwapFee new swap fee to be applied on future transactions
   */
  function setSwapFee(Swap storage self, uint256 newSwapFee) external {
    require(newSwapFee <= MAX_SWAP_FEE, "LML:Fee is too high");
    self.swapFee = newSwapFee;

    emit NewSwapFee(newSwapFee);
  }
}
