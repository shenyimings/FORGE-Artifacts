// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
import { Bank } from "src/Bank.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";
import { IPancakeV3MasterChef } from "src/interfaces/pancake-v3/IPancakeV3MasterChef.sol";
import { IChainlinkAggregator } from "src/interfaces/IChainlinkAggregator.sol";

import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { LibSqrtPriceX96 } from "src/libraries/LibSqrtPriceX96.sol";
import { LibLiquidityAmounts } from "src/libraries/LibLiquidityAmounts.sol";
import { LibFullMath } from "src/libraries/LibFullMath.sol";
import { LibFixedPoint128 } from "src/libraries/LibFixedPoint128.sol";

import { IVaultReader } from "src/interfaces/IVaultReader.sol";

contract PancakeV3VaultReader is IVaultReader {
  AutomatedVaultManager internal immutable automatedVaultManager;
  PancakeV3VaultOracle internal immutable pancakeV3VaultOracle;
  Bank internal immutable bank;
  address internal constant cake = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
  IChainlinkAggregator internal constant cakePriceFeed =
    IChainlinkAggregator(0xB6064eD41d4f67e353768aA239cA86f4F73665a1);

  constructor(address _automatedVaultManager, address _bank, address _pancakeV3VaultOracle) {
    automatedVaultManager = AutomatedVaultManager(_automatedVaultManager);
    bank = Bank(_bank);
    pancakeV3VaultOracle = PancakeV3VaultOracle(_pancakeV3VaultOracle);
  }

  function getVaultSummary(address _vaultToken) public view returns (VaultSummary memory _vaultSummary) {
    // prerequisites
    address _worker = automatedVaultManager.getWorker(_vaultToken);
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();
    uint256 _tokenId = PancakeV3Worker(_worker).nftTokenId();
    (uint160 _poolSqrtPriceX96,,,,,,) = ICommonV3Pool(PancakeV3Worker(_worker).pool()).slot0();
    (,,,,, int24 _tickLower, int24 _tickUpper, uint128 _liquidity,,,,) =
      PancakeV3Worker(_worker).nftPositionManager().positions(_tokenId);

    // assign values
    _vaultSummary.token0price = pancakeV3VaultOracle.getTokenPrice(address(_token0));
    _vaultSummary.token1price = pancakeV3VaultOracle.getTokenPrice(address(_token1));
    _vaultSummary.token0Undeployed = _token0.balanceOf(_worker);
    _vaultSummary.token1Undeployed = _token1.balanceOf(_worker);

    (, _vaultSummary.token0Debt) = bank.getVaultDebt(_vaultToken, address(_token0));
    (, _vaultSummary.token1Debt) = bank.getVaultDebt(_vaultToken, address(_token1));

    (_vaultSummary.token0Farmed, _vaultSummary.token1Farmed) = LibLiquidityAmounts.getAmountsForLiquidity(
      _poolSqrtPriceX96,
      LibTickMath.getSqrtRatioAtTick(_tickLower),
      LibTickMath.getSqrtRatioAtTick(_tickUpper),
      _liquidity
    );

    _vaultSummary.lowerPrice = _tickToPrice(_tickLower, _token0.decimals(), _token1.decimals());
    _vaultSummary.upperPrice = _tickToPrice(_tickUpper, _token0.decimals(), _token1.decimals());
  }

  function _tickToPrice(int24 _tick, uint256 _token0Decimals, uint256 _token1Decimals)
    internal
    pure
    returns (uint256 _price)
  {
    // tick => sqrtPriceX96 => price
    uint160 _sqrtPriceX96 = LibTickMath.getSqrtRatioAtTick(_tick);
    _price = LibSqrtPriceX96.decodeSqrtPriceX96(_sqrtPriceX96, _token0Decimals, _token1Decimals);
  }

  function getVaultSharePrice(address _vaultToken)
    external
    view
    returns (uint256 _sharePrice, uint256 _sharePriceWithManagementFee)
  {
    VaultSummary memory _vautlSummary = getVaultSummary(_vaultToken);

    uint256 _totalEquity;

    // Stack too deep
    {
      address _worker = automatedVaultManager.getWorker(_vaultToken);
      uint256 _tokenId = PancakeV3Worker(_worker).nftTokenId();

      // Find pending cake equity
      uint256 _cakeEquity;
      {
        uint256 _pendingCake = IPancakeV3MasterChef(PancakeV3Worker(_worker).masterChef()).pendingCake(_tokenId);
        (, int256 _cakePrice,,,) = cakePriceFeed.latestRoundData();
        // cake price is 8 decimals, cake itself is 18 decimals
        _cakeEquity = _pendingCake * uint256(_cakePrice) / 1e8;
      }

      // Find uncollected trading fee amount
      (uint256 _token0TradingFee, uint256 _token1TradingFee) =
        _getPositionFees(_tokenId, PancakeV3Worker(_worker).nftPositionManager(), PancakeV3Worker(_worker).pool());

      // TODO: include pending interest after upgrade mm
      uint256 _token0PositionValue = (_vautlSummary.token0Undeployed + _vautlSummary.token0Farmed + _token0TradingFee)
        * _vautlSummary.token0price / 1e18;
      uint256 _token0DebtValue = _vautlSummary.token0Debt * _vautlSummary.token0price / 1e18;
      uint256 _token1PositionValue = (_vautlSummary.token1Undeployed + _vautlSummary.token1Farmed + _token1TradingFee)
        * _vautlSummary.token1price / 1e18;
      uint256 _token1DebtValue = _vautlSummary.token1Debt * _vautlSummary.token1price / 1e18;
      _totalEquity = _token0PositionValue + _token1PositionValue + _cakeEquity - _token0DebtValue - _token1DebtValue;
    }

    uint256 _vaultTotalSupply = ERC20(_vaultToken).totalSupply();
    uint256 _pendingManagementFee = automatedVaultManager.pendingManagementFee(_vaultToken);

    // Return value
    _sharePrice = _totalEquity * 1e18 / _vaultTotalSupply;
    _sharePriceWithManagementFee = _totalEquity * 1e18 / (_vaultTotalSupply + _pendingManagementFee);
  }

  struct FeeParams {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    uint256 positionFeeGrowthInside0LastX128;
    uint256 positionFeeGrowthInside1LastX128;
    uint256 tokensOwed0;
    uint256 tokensOwed1;
  }

  function getPendingRewards(address _vaultToken) external view returns (TokenAmount[] memory pendingRewards) {
    address _worker = automatedVaultManager.getWorker(_vaultToken);
    uint256 _tokenId = PancakeV3Worker(_worker).nftTokenId();

    (uint256 token0TradingFee, uint256 token1TradingFee) =
      _getPositionFees(_tokenId, PancakeV3Worker(_worker).nftPositionManager(), PancakeV3Worker(_worker).pool());
    uint256 rewardAmount = IPancakeV3MasterChef(PancakeV3Worker(_worker).masterChef()).pendingCake(_tokenId);

    pendingRewards = new TokenAmount[](3);
    pendingRewards[0] = TokenAmount({ token: address(PancakeV3Worker(_worker).token0()), amount: token0TradingFee });
    pendingRewards[1] = TokenAmount({ token: address(PancakeV3Worker(_worker).token1()), amount: token1TradingFee });
    pendingRewards[2] = TokenAmount({ token: cake, amount: rewardAmount });
  }

  function _getPositionFees(uint256 tokenId, ICommonV3PositionManager positionManager, ICommonV3Pool pool)
    private
    view
    returns (uint256 amount0, uint256 amount1)
  {
    if (tokenId == 0) return (amount0, amount1);

    (
      ,
      ,
      ,
      ,
      ,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      uint256 positionFeeGrowthInside0LastX128,
      uint256 positionFeeGrowthInside1LastX128,
      uint256 tokensOwed0,
      uint256 tokensOwed1
    ) = positionManager.positions(tokenId);

    (uint256 poolFeeGrowthInside0LastX128, uint256 poolFeeGrowthInside1LastX128) =
      _getFeeGrowthInside(pool, tickLower, tickUpper);

    amount0 = LibFullMath.mulDiv(
      poolFeeGrowthInside0LastX128 - positionFeeGrowthInside0LastX128, liquidity, LibFixedPoint128.Q128
    ) + tokensOwed0;

    amount1 = LibFullMath.mulDiv(
      poolFeeGrowthInside1LastX128 - positionFeeGrowthInside1LastX128, liquidity, LibFixedPoint128.Q128
    ) + tokensOwed1;
  }

  function _getFeeGrowthInside(ICommonV3Pool pool, int24 tickLower, int24 tickUpper)
    private
    view
    returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
  {
    (, int24 tickCurrent,,,,,) = pool.slot0();
    (,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,) = pool.ticks(tickLower);
    (,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,) = pool.ticks(tickUpper);

    if (tickCurrent < tickLower) {
      feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
      feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
    } else if (tickCurrent < tickUpper) {
      uint256 feeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128();
      uint256 feeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128();
      feeGrowthInside0X128 = feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
      feeGrowthInside1X128 = feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
    } else {
      feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
      feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
    }
  }

  struct RepurchaseSummary {
    address borrowToken; // token to borrow when repurchase, the other token will be repay token
    address stableToken;
    address assetToken;
    int256 exposureAmount; // in assetToken
    uint256 stableTokenPrice;
    uint256 assetTokenPrice;
  }

  function getRepurchaseSummary(address _vaultToken) external view returns (RepurchaseSummary memory _result) {
    address _worker = automatedVaultManager.getWorker(_vaultToken);

    bool _isToken0Base = PancakeV3Worker(_worker).isToken0Base();
    if (_isToken0Base) {
      _result.stableToken = address(PancakeV3Worker(_worker).token0());
      _result.assetToken = address(PancakeV3Worker(_worker).token1());
    } else {
      _result.stableToken = address(PancakeV3Worker(_worker).token1());
      _result.assetToken = address(PancakeV3Worker(_worker).token0());
    }

    _result.exposureAmount = pancakeV3VaultOracle.getExposure(_vaultToken, _worker);
    // if exposure is long, borrow asset token to decrease exposure, vice versa
    _result.borrowToken = _result.exposureAmount > 0 ? _result.assetToken : _result.stableToken;
    _result.stableTokenPrice = pancakeV3VaultOracle.getTokenPrice(_result.stableToken);
    _result.assetTokenPrice = pancakeV3VaultOracle.getTokenPrice(_result.assetToken);
  }
}
