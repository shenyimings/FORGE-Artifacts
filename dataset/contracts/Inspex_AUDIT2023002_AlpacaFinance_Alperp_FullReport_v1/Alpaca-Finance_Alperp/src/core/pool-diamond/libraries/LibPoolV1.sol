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

import { StrategyInterface } from "../../../interfaces/StrategyInterface.sol";
import { ALP } from "../../../tokens/ALP.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { PoolOracle } from "../../PoolOracle.sol";
import { FarmFacetInterface } from "../interfaces/FarmFacetInterface.sol";
import { LibPoolConfigV1 } from "./LibPoolConfigV1.sol";

library LibPoolV1 {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  error LibPoolV1_BadSubAccountId();
  error LibPoolV1_Forbidden();
  error LibPoolV1_LiquidityMismatch();
  error LibPoolV1_InsufficientLiquidity();
  error LibPoolV1_OverUsdDebtCeiling();
  error LibPoolV1_OverShortCeiling();
  error LibPoolV1_OverOpenInterestLongCeiling();
  error LibPoolV1_ForbiddenPlugin();

  // -------------
  //   Constants
  // -------------
  // POOL_V1_STORAGE_POSITION = keccak256("com.alperp.poolv1.diamond.storage")
  bytes32 internal constant POOL_V1_STORAGE_POSITION =
    0x08ea6422ce99418d00e8263f9b0197bfe0b74fd7e7dd9b1fcb2ad20910f18b27;

  enum MinMax {
    MIN,
    MAX
  }

  // -------------
  //    Storage
  // -------------
  struct Position {
    address primaryAccount;
    uint256 size;
    uint256 collateral; // collateral value in USD
    uint256 averagePrice;
    uint256 entryBorrowingRate;
    int256 entryFundingRate;
    uint256 reserveAmount;
    int256 realizedPnl;
    uint256 lastIncreasedTime;
    uint256 openInterest;
    int256 fundingFeeDebt;
  }

  struct PoolV1DiamondStorage {
    // Dependent contracts
    ALP alp;
    PoolOracle oracle;
    // Liquidity
    mapping(address => uint256) totalOf;
    mapping(address => uint256) liquidityOf;
    mapping(address => uint256) reservedOf;
    mapping(address => uint256) sumBorrowingRateOf;
    mapping(address => uint256) lastFundingTimeOf;
    // Short
    mapping(address => uint256) shortSizeOf;
    mapping(address => uint256) shortAveragePriceOf;
    // Fee
    mapping(address => uint256) feeReserveOf;
    // Debt
    uint256 totalUsdDebt;
    mapping(address => uint256) usdDebtOf;
    mapping(address => uint256) guaranteedUsdOf;
    // AUM
    uint256 additionalAum;
    uint256 discountedAum;
    // Position
    mapping(bytes32 => Position) positions;
    // Open Interests in token amount with that token decimals
    mapping(address => uint256) openInterestLong;
    mapping(address => uint256) openInterestShort;
    // Funding Rate
    mapping(address => int256) accumFundingRateLong;
    mapping(address => int256) accumFundingRateShort;
    // Funding Fee Accounting
    uint256 fundingFeePayable;
    uint256 fundingFeeReceivable;
    // Plugins
    mapping(address => mapping(address => bool)) approvedPlugins;
    mapping(address => bool) plugins;
  }

  // -----------
  //   Events
  // -----------
  event DecreaseGuaranteedUsd(address token, uint256 amount);
  event DecreasePoolLiquidity(address token, uint256 amount);
  event DecreaseUsdDebt(address token, uint256 amount);
  event DecreaseReserved(address token, uint256 amount);
  event DecreaseShortSize(address token, uint256 amount);
  event IncreaseGuaranteedUsd(address token, uint256 amount);
  event IncreasePoolLiquidity(address token, uint256 amount);
  event IncreaseUsdDebt(address token, uint256 amount);
  event IncreaseReserved(address token, uint256 amount);
  event IncreaseShortSize(address token, uint256 amount);
  event SetPoolConfig(address prevPoolConfig, address newPoolConfig);
  event SetPoolOracle(address prevPoolOracle, address newPoolOracle);
  event IncreaseOpenInterest(bool isLong, address indexToken, uint256 value);
  event DecreaseOpenInterest(bool isLong, address indexToken, uint256 value);
  event StrategyDivest(address token, uint256 actualAmountIn);

  function poolV1DiamondStorage()
    internal
    pure
    returns (PoolV1DiamondStorage storage poolV1ds)
  {
    assembly {
      poolV1ds.slot := POOL_V1_STORAGE_POSITION
    }
  }

  function setALP(ALP newALP) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();
    poolV1ds.alp = newALP;
  }

  function setPoolOracle(PoolOracle newOracle) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();
    emit SetPoolOracle(address(poolV1ds.oracle), address(newOracle));
    poolV1ds.oracle = newOracle;
  }

  // --------------
  // Access Control
  // --------------
  function allowed(address account) internal view {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();
    // Load PoolConfigV1 diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigds = LibPoolConfigV1.poolConfigV1DiamondStorage();

    if (account != msg.sender && poolConfigds.router != msg.sender) {
      if (!poolV1ds.plugins[msg.sender]) {
        revert LibPoolV1_ForbiddenPlugin();
      }
      if (!poolV1ds.approvedPlugins[account][msg.sender])
        revert LibPoolV1_Forbidden();
    }
  }

  // -----------------
  // Queries functions
  // -----------------
  function getPositionId(
    address account,
    address collateralToken,
    address indexToken,
    bool isLong
  ) internal pure returns (bytes32) {
    return
      keccak256(abi.encodePacked(account, collateralToken, indexToken, isLong));
  }

  function getSubAccount(address primary, uint256 subAccountId)
    internal
    pure
    returns (address)
  {
    if (subAccountId > 255) revert LibPoolV1_BadSubAccountId();
    return address(uint160(primary) ^ uint160(subAccountId));
  }

  // ------------------------------
  // Liquidity alteration functions
  // ------------------------------

  function increasePoolLiquidity(address token, uint256 amount) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    LibPoolConfigV1.StrategyData memory strategyData = poolConfigDs
      .strategyDataOf[token];

    poolV1ds.liquidityOf[token] += amount;
    if (
      IERC20(token).balanceOf(address(this)) + strategyData.principle <
      poolV1ds.liquidityOf[token]
    ) revert LibPoolV1_LiquidityMismatch();
    emit IncreasePoolLiquidity(token, amount);
  }

  function decreasePoolLiquidity(address token, uint256 amount) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    poolV1ds.liquidityOf[token] -= amount;
    if (poolV1ds.liquidityOf[token] < poolV1ds.reservedOf[token])
      revert LibPoolV1_InsufficientLiquidity();
    emit DecreasePoolLiquidity(token, amount);
  }

  function increaseUsdDebt(address token, uint256 amount) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    poolV1ds.usdDebtOf[token] += amount;

    // SLOAD
    uint256 newUsdDebt = poolV1ds.usdDebtOf[token];
    uint256 usdDebtCeiling = LibPoolConfigV1.getTokenUsdDebtCeilingOf(token);

    if (usdDebtCeiling != 0) {
      if (newUsdDebt > usdDebtCeiling) revert LibPoolV1_OverUsdDebtCeiling();
    }

    emit IncreaseUsdDebt(token, amount);
  }

  function decreaseUsdDebt(address token, uint256 amount) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    uint256 usdDebt = poolV1ds.usdDebtOf[token];
    if (usdDebt <= amount) {
      poolV1ds.usdDebtOf[token] = 0;
      emit DecreaseUsdDebt(token, usdDebt);
      return;
    }

    poolV1ds.usdDebtOf[token] = usdDebt - amount;

    emit DecreaseUsdDebt(token, amount);
  }

  function increaseReserved(address token, uint256 amount) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    poolV1ds.reservedOf[token] += amount;
    if (poolV1ds.reservedOf[token] > poolV1ds.liquidityOf[token])
      revert LibPoolV1_InsufficientLiquidity();
    emit IncreaseReserved(token, amount);
  }

  function decreaseReserved(address token, uint256 amount) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    poolV1ds.reservedOf[token] -= amount;
    emit DecreaseReserved(token, amount);
  }

  function increaseGuaranteedUsd(address token, uint256 amountUsd) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    poolV1ds.guaranteedUsdOf[token] += amountUsd;
    emit IncreaseGuaranteedUsd(token, amountUsd);
  }

  function decreaseGuaranteedUsd(address token, uint256 amountUsd) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    poolV1ds.guaranteedUsdOf[token] -= amountUsd;
    emit DecreaseGuaranteedUsd(token, amountUsd);
  }

  function increaseShortSize(address token, uint256 amountUsd) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    // SLOAD
    uint256 shortCeiling = LibPoolConfigV1.getTokenShortCeilingOf(token);
    poolV1ds.shortSizeOf[token] += amountUsd;

    if (shortCeiling != 0) {
      if (poolV1ds.shortSizeOf[token] > shortCeiling)
        revert LibPoolV1_OverShortCeiling();
    }

    emit IncreaseShortSize(token, amountUsd);
  }

  function decreaseShortSize(address token, uint256 amountUsd) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    uint256 shortSize = poolV1ds.shortSizeOf[token];
    if (amountUsd > shortSize) {
      poolV1ds.shortSizeOf[token] = 0;
      return;
    }

    poolV1ds.shortSizeOf[token] -= amountUsd;

    emit DecreaseShortSize(token, amountUsd);
  }

  function updateTotalOf(address token) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();
    poolV1ds.totalOf[token] = IERC20(token).balanceOf(address(this));
  }

  // ------------------------------
  // Farmable liquidity alteration functions
  // ------------------------------
  function realizedFarmPnL(address token) internal {
    // Load PoolConfigV1 diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigV1ds = LibPoolConfigV1.poolConfigV1DiamondStorage();

    StrategyInterface strategy = poolConfigV1ds.strategyOf[token];

    if (address(strategy) != address(0))
      FarmFacetInterface(address(this)).farm(token, false);
  }

  function tokenOut(
    address token,
    address to,
    uint256 amountOut
  ) internal {
    // Load PoolV1 diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    // Load PoolConfigV1 diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigV1ds = LibPoolConfigV1.poolConfigV1DiamondStorage();

    StrategyInterface strategy = poolConfigV1ds.strategyOf[token];
    uint256 balance = IERC20(token).balanceOf(address(this));
    uint256 feeReserve = poolV1ds.feeReserveOf[token];
    if (address(strategy) != address(0)) {
      // Find amountIn for strategy's withdrawal
      uint256 amountIn;
      // If balance is not enough, need to withdraw from strategy
      // - If balance is not even enough for feeReserve, withdraw based on amountOut + extraAmount for the feeReserve
      // - If balance is enough for feeReserve, withdraw based on amountOut - balance excluded the feeReserve
      if (feeReserve > balance) {
        uint256 feeOut = feeReserve - balance;
        amountIn = amountOut + feeOut;
      } else if (balance - feeReserve < amountOut) {
        uint256 poolBalance = balance - feeReserve;
        amountIn = amountOut - poolBalance;
      }

      // If amount to be withdrawn > 0, withdraw from strategy
      if (amountIn > 0) {
        // Handle when physical tokens in Pool < amountOut, then we need to withdraw from strategy.
        LibPoolConfigV1.StrategyData storage strategyData = poolConfigV1ds
          .strategyDataOf[token];

        // Witthdraw funds from strategy
        uint256 actualAmountIn = strategy.withdraw(amountIn);
        // Update totalOf[token] to sync physical balance with pool state
        updateTotalOf(token);

        // Update how much pool put in the strategy
        strategyData.principle -= actualAmountIn.toUint128();
      }
    }

    pushTokens(token, to, amountOut);
  }

  /// ---------------------------
  /// ERC20 interaction functions
  /// ---------------------------

  function pullTokens(address token) internal returns (uint256) {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    uint256 prevBalance = poolV1ds.totalOf[token];
    uint256 nextBalance = IERC20(token).balanceOf(address(this));

    poolV1ds.totalOf[token] = nextBalance;

    return nextBalance - prevBalance;
  }

  function pushTokens(
    address token,
    address to,
    uint256 amount
  ) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    IERC20(token).safeTransfer(to, amount);
    poolV1ds.totalOf[token] = IERC20(token).balanceOf(address(this));
  }

  /// --------------------
  /// Conversion functions
  /// --------------------
  function convertTokenDecimals(
    uint256 fromTokenDecimals,
    uint256 toTokenDecimals,
    uint256 amount
  ) internal pure returns (uint256) {
    return (amount * 10**toTokenDecimals) / 10**fromTokenDecimals;
  }

  function convertUsde30ToTokens(
    address token,
    uint256 amountUsd,
    bool isUseMaxPrice
  ) internal view returns (uint256) {
    if (amountUsd == 0) return 0;

    // Load PoolV1 diamond storage
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    return
      (amountUsd * (10**LibPoolConfigV1.getTokenDecimalsOf(token))) /
      poolV1ds.oracle.getPrice(token, isUseMaxPrice);
  }

  function convertUsde30ToTokens(
    address token,
    int256 amountUsd,
    bool isUseMaxPrice
  ) internal view returns (int256) {
    if (amountUsd == 0) return 0;

    // Load PoolV1 diamond storage
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    return
      (amountUsd * int256(10**LibPoolConfigV1.getTokenDecimalsOf(token))) /
      int256(poolV1ds.oracle.getPrice(token, isUseMaxPrice));
  }

  function convertTokensToUsde30(
    address token,
    uint256 amountTokens,
    bool isUseMaxPrice
  ) internal view returns (uint256) {
    if (amountTokens == 0) return 0;

    // Load PoolV1 diamond storage
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    return
      (amountTokens * poolV1ds.oracle.getPrice(token, isUseMaxPrice)) /
      (10**LibPoolConfigV1.getTokenDecimalsOf(token));
  }

  function increaseOpenInterest(
    bool isLong,
    address indexToken,
    uint256 amount
  ) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    if (isLong) {
      poolV1ds.openInterestLong[indexToken] += amount;
      uint256 openInterestLongCeiling = LibPoolConfigV1
        .getTokenOpenInterestLongCeilingOf(indexToken);
      if (
        openInterestLongCeiling > 0 &&
        poolV1ds.openInterestLong[indexToken] > openInterestLongCeiling
      ) {
        revert LibPoolV1_OverOpenInterestLongCeiling();
      }
    } else {
      poolV1ds.openInterestShort[indexToken] += amount;
    }
    emit IncreaseOpenInterest(isLong, indexToken, amount);
  }

  function decreaseOpenInterest(
    bool isLong,
    address indexToken,
    uint256 amount
  ) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    if (isLong) {
      poolV1ds.openInterestLong[indexToken] -= amount;
    } else {
      poolV1ds.openInterestShort[indexToken] -= amount;
    }
    emit DecreaseOpenInterest(isLong, indexToken, amount);
  }

  function updateFundingFeeAccounting(int256 fundingFee) internal {
    PoolV1DiamondStorage storage poolV1ds = poolV1DiamondStorage();

    if (fundingFee < 0) {
      poolV1ds.fundingFeeReceivable += uint256(-fundingFee);
    } else {
      poolV1ds.fundingFeePayable += uint256(fundingFee);
    }

    if (poolV1ds.fundingFeeReceivable > 0 && poolV1ds.fundingFeePayable > 0) {
      if (poolV1ds.fundingFeeReceivable > poolV1ds.fundingFeePayable) {
        poolV1ds.fundingFeeReceivable -= poolV1ds.fundingFeePayable;
        poolV1ds.fundingFeePayable = 0;
      } else {
        poolV1ds.fundingFeePayable -= poolV1ds.fundingFeeReceivable;
        poolV1ds.fundingFeeReceivable = 0;
      }
    }
  }
}
