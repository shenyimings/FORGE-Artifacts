// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import "src/oracles/BaseOracle.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { Bank } from "src/Bank.sol";

// interfaces
import { IVaultOracle } from "src/interfaces/IVaultOracle.sol";
import { IERC20 } from "src/interfaces/IERC20.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";

// libraries
import { LibFullMath } from "src/libraries/LibFullMath.sol";
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { LibLiquidityAmounts } from "src/libraries/LibLiquidityAmounts.sol";
import { LibSqrtPriceX96 } from "src/libraries/LibSqrtPriceX96.sol";
import { MAX_BPS } from "src/libraries/Constants.sol";

contract PancakeV3VaultOracle is BaseOracle, IVaultOracle {
  /// States
  ICommonV3PositionManager public positionManager;
  uint16 public maxPriceDiff;
  Bank public bank;

  /// Errors
  error PancakeV3VaultOracle_OraclePriceTooLow();
  error PancakeV3VaultOracle_OraclePriceTooHigh();
  error PancakeV3VaultOracle_InvalidParams();

  /// Events
  event LogSetMaxPriceDiff(uint16 prevMaxPriceDiff, uint16 maxPriceDiff);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _positionManager, address _bank, uint16 _maxPriceAge, uint16 _maxPriceDiff)
    external
    initializer
  {
    if (_maxPriceDiff < MAX_BPS) {
      revert PancakeV3VaultOracle_InvalidParams();
    }
    Ownable2StepUpgradeable.__Ownable2Step_init();

    positionManager = ICommonV3PositionManager(_positionManager);
    bank = Bank(_bank);
    maxPriceAge = _maxPriceAge;
    maxPriceDiff = _maxPriceDiff;
  }

  /// @notice Set max price diff.
  /// @param _newMaxPriceDiff Max price diff in bps.
  function setMaxPriceDiff(uint16 _newMaxPriceDiff) external onlyOwner {
    if (_newMaxPriceDiff < MAX_BPS) {
      revert PancakeV3VaultOracle_InvalidParams();
    }
    emit LogSetMaxPriceDiff(maxPriceDiff, _newMaxPriceDiff);
    maxPriceDiff = _newMaxPriceDiff;
  }

  /// @notice Get value of a nft position. Tokens value are determined by Chainlink price feeds
  /// and compared against pool's sqrtPriceX96 to protect against price manipulation.
  /// Revert on price deviation above threshold defined.
  /// Note that there is minor precision loss during conversion of sqrtPriceX96. The loss is further amplified by tick range.
  /// The narrower the range, the higher the precision loss.
  /// @param _pool Pool address that `_tokenId` belongs to
  /// @param _tokenId Nft's tokenId
  /// @return _valueUSD USD value of liquidity that nft holds. In 18 decimals.
  function _getPositionValueUSD(address _pool, uint256 _tokenId, uint256 _token0OraclePrice, uint256 _token1OraclePrice)
    internal
    view
    returns (uint256 _valueUSD)
  {
    uint256 _token0Decimals;
    uint256 _token1Decimals;
    int24 _tickLower;
    int24 _tickUpper;
    uint128 _liquidity;
    {
      // Load position data
      address _token0;
      address _token1;
      (,, _token0, _token1,, _tickLower, _tickUpper, _liquidity,,,,) = positionManager.positions(_tokenId);
      // Tokens decimals
      _token0Decimals = IERC20(_token0).decimals();
      _token1Decimals = IERC20(_token1).decimals();
    }

    uint256 _oraclePriceE18 = _token0OraclePrice * 1e18 / _token1OraclePrice;

    // Check price deviation between oracle and pool
    {
      // Get pool sqrtPriceX96
      (uint160 _poolSqrtPriceX96,,,,,,) = ICommonV3Pool(_pool).slot0();
      // Convert pool sqrt price to priceE18
      uint256 _poolPriceE18 = LibSqrtPriceX96.decodeSqrtPriceX96(_poolSqrtPriceX96, _token0Decimals, _token1Decimals);
      uint16 _cachedMaxPriceDiff = maxPriceDiff;
      if (_poolPriceE18 * 10000 > _oraclePriceE18 * _cachedMaxPriceDiff) {
        revert PancakeV3VaultOracle_OraclePriceTooLow();
      }
      if (_poolPriceE18 * _cachedMaxPriceDiff < _oraclePriceE18 * 10000) {
        revert PancakeV3VaultOracle_OraclePriceTooHigh();
      }
    }

    // Get amount based on converted oracle price
    uint256 _oracleAmount0;
    uint256 _oracleAmount1;
    {
      uint160 _oracleSqrtPriceX96 =
        LibSqrtPriceX96.encodeSqrtPriceX96(_oraclePriceE18, _token0Decimals, _token1Decimals);
      (_oracleAmount0, _oracleAmount1) = LibLiquidityAmounts.getAmountsForLiquidity(
        _oracleSqrtPriceX96,
        LibTickMath.getSqrtRatioAtTick(_tickLower),
        LibTickMath.getSqrtRatioAtTick(_tickUpper),
        _liquidity
      );
    }

    // Convert to usd according to oracle prices
    if (_oracleAmount0 != 0) {
      _valueUSD += LibFullMath.mulDiv(_oracleAmount0, _token0OraclePrice, (10 ** _token0Decimals));
    }
    if (_oracleAmount1 != 0) {
      _valueUSD += LibFullMath.mulDiv(_oracleAmount1, _token1OraclePrice, (10 ** _token1Decimals));
    }

    return _valueUSD;
  }

  function _getDebtValueUSD(
    address _vaultToken,
    address _token0,
    address _token1,
    uint256 _token0OraclePrice,
    uint256 _token1OraclePrice
  ) internal view returns (uint256 _debtValueUSD) {
    (, uint256 _token0Debt) = bank.getVaultDebt(_vaultToken, _token0);
    (, uint256 _token1Debt) = bank.getVaultDebt(_vaultToken, _token1);
    return _token0Debt * _token0OraclePrice / (10 ** IERC20(_token0).decimals())
      + _token1Debt * _token1OraclePrice / (10 ** IERC20(_token1).decimals());
  }

  function getEquityAndDebt(address _vaultToken, address _pancakeV3Worker)
    external
    view
    override
    returns (uint256 _equityUSD, uint256 _debtValUSD)
  {
    ICommonV3Pool _pool = PancakeV3Worker(_pancakeV3Worker).pool();
    address _token0 = address(_pool.token0());
    address _token1 = address(_pool.token1());

    // Get prices from oracle
    uint256 _token0OraclePrice = _safeGetTokenPriceE18(_token0);
    uint256 _token1OraclePrice = _safeGetTokenPriceE18(_token1);

    // Get nft position value. Skip if worker didn't hold any nft (tokenId = 0)
    uint256 _posValUSD;
    {
      uint256 _tokenId = PancakeV3Worker(_pancakeV3Worker).nftTokenId();
      _posValUSD =
        _tokenId == 0 ? 0 : _getPositionValueUSD(address(_pool), _tokenId, _token0OraclePrice, _token1OraclePrice);
    }
    _debtValUSD = _getDebtValueUSD(_vaultToken, _token0, _token1, _token0OraclePrice, _token1OraclePrice);
    uint256 _tokenValUSD = IERC20(_token0).balanceOf(_pancakeV3Worker) * _token0OraclePrice
      / (10 ** IERC20(_token0).decimals())
      + IERC20(_token1).balanceOf(_pancakeV3Worker) * _token1OraclePrice / (10 ** IERC20(_token1).decimals());

    return (_posValUSD + _tokenValUSD - _debtValUSD, _debtValUSD);
  }

  /// @notice Exposure = position + undeployed - debt
  function getExposure(address _vaultToken, address _pancakeV3Worker) external view returns (int256 _exposure) {
    uint256 _farmAmount;
    address _volatileToken;
    bool _isToken0Base = PancakeV3Worker(_pancakeV3Worker).isToken0Base();

    uint256 _tokenId = PancakeV3Worker(_pancakeV3Worker).nftTokenId();
    if (_tokenId == 0) {
      // Skip farm amount calculation if worker didn't hold any nft (tokenId = 0)
      _volatileToken = _isToken0Base
        ? address(PancakeV3Worker(_pancakeV3Worker).pool().token1())
        : address(PancakeV3Worker(_pancakeV3Worker).pool().token0());
    } else {
      // Load position data
      (,, address _token0, address _token1,, int24 _tickLower, int24 _tickUpper, uint128 _liquidity,,,,) =
        positionManager.positions(PancakeV3Worker(_pancakeV3Worker).nftTokenId());
      // Find volatile token to base exposure on
      _volatileToken = _isToken0Base ? _token1 : _token0;

      // Get amount in farm position
      {
        // Use pool price to calculate amount
        (uint160 _poolSqrtPriceX96,,,,,,) = PancakeV3Worker(_pancakeV3Worker).pool().slot0();
        (uint256 _amount0, uint256 _amount1) = LibLiquidityAmounts.getAmountsForLiquidity(
          _poolSqrtPriceX96,
          LibTickMath.getSqrtRatioAtTick(_tickLower),
          LibTickMath.getSqrtRatioAtTick(_tickUpper),
          _liquidity
        );
        _farmAmount = _isToken0Base ? _amount1 : _amount0;
      }
    }

    // Get debt amount
    (, uint256 _debtAmount) = bank.getVaultDebt(_vaultToken, _volatileToken);

    _exposure = int256(_farmAmount + IERC20(_volatileToken).balanceOf(_pancakeV3Worker)) - int256(_debtAmount);
  }
}
