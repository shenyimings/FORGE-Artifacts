// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20, ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { ILendingPool } from "../interfaces/radiant/ILendingPool.sol";
import { IWETHGateway } from "../interfaces/radiant/IWETHGateway.sol";
import { ICreditDelegationToken } from "../interfaces/radiant/ICreditDelegationToken.sol";
import { IChefIncentivesController } from "../interfaces/radiant/IChefIncentivesController.sol";
import { IMultiFeeDistribution } from "../interfaces/radiant/IMultiFeeDistribution.sol";
import { IFeeDistribution } from "../interfaces/radiant/IFeeDistribution.sol";
import { IEligibilityDataProvider } from "../interfaces/radiant/IEligibilityDataProvider.sol";
import { IIncentivizedERC20 } from "../interfaces/radiant/IIncentivizedERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { DataTypes } from "./radiant/DataTypes.sol";
import { ReserveConfiguration } from "./radiant/ReserveConfiguration.sol";

library RadiantUtilLib {
    using SafeERC20 for IERC20;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    /* ============ Structs ============ */

    struct PositionStats {
        uint256 totalCollateralETH;
        uint256 totalDebtETH;
        uint256 currentLiquidationThreshold;
        uint256 ltv;
        uint256 healthFactor;
        uint256 maxWithdrawETH;
        uint256 availableBorrowsETH;
        address targetAsset;
        uint256 maxWithdrawAmount;
        uint256 maxBorrowableAmount;
    }

    uint256 public constant NORMALIZED = 10 ** 12;
    uint256 public constant DENOMINATOR = 10000;

    /* ============ Errors ============ */

    error NotSupportedToken();
    error HealthFactorTooLow();
    error RDNTEligibilityTooLow();

    /* ============ Events ============ */

    event AssetLooping(address indexed asset, uint256 amountBorrowed);
    event Deleverage(address indexed asset, uint256 amountRepaid);

    /* ============ Read ============ */

    function claimableDlpRewards(
        IMultiFeeDistribution mdf,
        address _user
    ) external view returns (address[] memory _rewardTokens, uint256[] memory _amounts) {
        IFeeDistribution.RewardData[] memory rewards = mdf.claimableRewards(_user);

        _rewardTokens = new address[](rewards.length);
        _amounts = new uint256[](rewards.length);

        for (uint256 i = 0; i < rewards.length; i++) {
            _rewardTokens[i] = rewards[i].token;
            _amounts[i] = rewards[i].amount;
        }
    }

    function rdntRewardStats(
        IChefIncentivesController chef,
        IMultiFeeDistribution mdf,
        address _user,
        address[] memory _tokens
    )
        external
        view
        returns (
            uint256 baseClaimable,
            uint256[] memory pendings,
            uint256 inVesting,
            uint256 vested
        )
    {
        baseClaimable = chef.userBaseClaimable(_user);
        pendings = chef.pendingRewards(_user, _tokens);

        (inVesting, vested, ) = mdf.earnedBalances(_user);
    }

    function rdntEligibility(
        IEligibilityDataProvider edp,
        ILendingPool _lendingPool,
        address _user
    )
        external
        view
        returns (
            bool isEligibleForRDNT,
            uint256 lockedDLPUSD,
            uint256 totalCollateralUSD,
            uint256 requiredDLPUSD,
            uint256 requiredDLPUSDWithTolerance
        )
    {
        isEligibleForRDNT = edp.isEligibleForRewards(_user);
        lockedDLPUSD = edp.lockedUsdValue(_user);
        (totalCollateralUSD, , , , , ) = _lendingPool.getUserAccountData(_user);
        requiredDLPUSD = edp.requiredUsdValue(_user);
        requiredDLPUSDWithTolerance =
            (requiredDLPUSD * edp.priceToleranceRatio()) /
            edp.RATIO_DIVISOR();
    }

    function quoteLeverage(
        ILendingPool _lendingPool,
        address _user,
        address _rToken
    ) internal view returns (PositionStats memory stats) {
        (
            stats.totalCollateralETH,
            stats.totalDebtETH,
            stats.availableBorrowsETH,
            stats.currentLiquidationThreshold,
            stats.ltv,
            stats.healthFactor
        ) = _lendingPool.getUserAccountData(_user);

        stats.maxWithdrawETH = ((stats.totalCollateralETH * stats.currentLiquidationThreshold) / DENOMINATOR) - stats.totalDebtETH;
        
        uint256 assetPriceETH = IIncentivizedERC20(_rToken).getAssetPrice();
        uint256 decimals = IIncentivizedERC20(_rToken).decimals();

        stats.maxWithdrawAmount = ((stats.maxWithdrawETH * (10 ** decimals)) / assetPriceETH);
        stats.maxBorrowableAmount = (stats.availableBorrowsETH * (10 ** decimals)) / assetPriceETH;
    }

    // calculate target vd balance to start deleverage, target vd is calculated based on health factor for this asset should be consistent before and after looping.
    // The amount to withdraw during deleverage also considering the part to repay and for user withdraw
    function calWithdraw(
        address _rToken,
        address _vdToken,
        address _user,
        uint256 _assetToWithdraw
    ) internal view returns (uint256) {
        uint256 totalDebt = IERC20(_vdToken).balanceOf(address(_user));
        uint256 repayAmount = (totalDebt * _assetToWithdraw) /
            (IERC20(_rToken).balanceOf(address(_user)) - totalDebt);
        uint256 targetVD = totalDebt > repayAmount ? totalDebt - repayAmount : 0;

        return targetVD;
    }

    function loopData(
        address _asset,
        uint256 _amount
    ) internal pure returns (address[] memory assetToloop, uint256[] memory vdTarget) {
        assetToloop = new address[](1);
        assetToloop[0] = _asset;

        vdTarget = new uint256[](1);
        vdTarget[0] = _amount;
    }

    /* ============ Validate ============ */

    function checkGoodState(
        IEligibilityDataProvider edp,
        ILendingPool _lendingPool,
        address _user,
        uint256 _miHealthFactor,
        bool _doRevert,
        bool _eligibiltyCheck
    ) external view returns (bool) {
        (, , , , , uint256 healthFactor) = _lendingPool.getUserAccountData(_user);
        if (healthFactor < _miHealthFactor) {
            if (_doRevert) revert HealthFactorTooLow();
            else return false;
        }

        if (address(edp) == address(0)) return true;

        if (_eligibiltyCheck) {
            if (!edp.isEligibleForRewards(_user)) {
                if (_doRevert) revert RDNTEligibilityTooLow();
                else return false;
            }
        }
        return true;
    }

    /* ============ Writes ============ */

    function _loop(
        ILendingPool _lendingPool,
        IWETHGateway _wethGateway,
        address _asset,
        address _rToken,
        address _vdToken,
        address _user,
        uint256 _targetVdBal,
        bool _isNative
    ) internal {
        uint256 vdBal = IERC20(_vdToken).balanceOf(_user);
        uint256 vdDiff = _targetVdBal - vdBal;

        while (vdDiff > 0) {
            RadiantUtilLib.PositionStats memory stats = RadiantUtilLib.quoteLeverage(
                _lendingPool,
                _user,
                _rToken
            );

            uint256 amountToBorrow = vdDiff > stats.maxBorrowableAmount
                ? stats.maxBorrowableAmount
                : vdDiff;

            RadiantUtilLib._depositHelper(
                _wethGateway,
                _lendingPool,
                _asset,
                _vdToken,
                amountToBorrow,
                _isNative,
                true
            );

            vdDiff -= amountToBorrow;

            emit AssetLooping(_asset, amountToBorrow);
        }
    }

    function _deleverage(
        ILendingPool _lendingPool,
        IWETHGateway _wethGateway,
        address _asset,
        address _rToken,
        address _vdToken,
        address _user,
        uint256 _targetVdBal,
        bool _isNative
    ) internal {
        uint256 vdBal = IERC20(_vdToken).balanceOf(address(this));
        uint256 vdDiff = vdBal - _targetVdBal;

        while (vdDiff > 0) {
            RadiantUtilLib.PositionStats memory stats = RadiantUtilLib.quoteLeverage(
                _lendingPool,
                address(_user),
                _rToken
            );
            uint256 amountToWithdraw = vdDiff > stats.maxWithdrawAmount
                ? stats.maxWithdrawAmount
                : vdDiff;

            uint256 assetRecAmount = RadiantUtilLib._safeWithdrawAsset(
                _wethGateway,
                _lendingPool,
                _asset,
                _rToken,
                amountToWithdraw,
                _isNative
            );

            RadiantUtilLib._repay(
                _wethGateway,
                _lendingPool,
                _asset,
                _rToken,
                assetRecAmount,
                _isNative
            );
            vdDiff -= amountToWithdraw;

            emit Deleverage(_asset, assetRecAmount);
        }
    }

    function _depositHelper(
        IWETHGateway _wethGateway,
        ILendingPool _lendingPool,
        address _asset,
        address _vdToken,
        uint256 _amount,
        bool isNative,
        bool _isFromBorrow
    ) internal {
        if (isNative) {
            if (_isFromBorrow) {
                ICreditDelegationToken(_vdToken).approveDelegation(address(_wethGateway), _amount);
                _wethGateway.borrowETH(address(_lendingPool), _amount, 2, 0);
            }
            _wethGateway.depositETH{ value: _amount }(address(_lendingPool), address(this), 0);
        } else {
            if (_isFromBorrow) {
                _lendingPool.borrow(_asset, _amount, 2, 0, address(this));
            }

            IERC20(_asset).safeApprove(address(_lendingPool), 0);
            IERC20(_asset).safeApprove(address(_lendingPool), _amount);
            
            _lendingPool.deposit(_asset, _amount, address(this), 0);
        }
    }

    /// @notice make sure when withdaw asset, it won't fail due to tiny amount difference amount.
    function _safeWithdrawAsset(
        IWETHGateway _wethGateway,
        ILendingPool _lendingPool,
        address _asset,
        address _rToken,
        uint256 _liquidity,
        bool _isNative
    ) internal returns (uint256) {
        uint256 rTokenBal = IERC20(_rToken).balanceOf(address(this));
        uint256 amountToWithdraw = _liquidity > rTokenBal ? rTokenBal : _liquidity;
        uint256 assetPrecBal = 0;
        uint256 asssetToReceive = 0;
        if (_isNative) {
            assetPrecBal = address(this).balance;
            IERC20(_rToken).approve(address(_wethGateway), amountToWithdraw);
            _wethGateway.withdrawETH(address(_lendingPool), amountToWithdraw, address(this));
            asssetToReceive = address(this).balance - assetPrecBal;
        } else {
            assetPrecBal = IERC20(_asset).balanceOf(address(this));
            _lendingPool.withdraw(_asset, amountToWithdraw, address(this));
            asssetToReceive = IERC20(_asset).balanceOf(address(this)) - assetPrecBal;
        }

        return asssetToReceive;
    }

    function _repay(
        IWETHGateway _wethGateway,
        ILendingPool _lendingPool,
        address _asset,
        address _rToken,
        uint256 _repayAmount,
        bool _isNative
    ) internal {
        if (_isNative) {
            IERC20(_rToken).approve(address(_wethGateway), _repayAmount);
            _wethGateway.repayETH{ value: _repayAmount }(
                address(_lendingPool),
                _repayAmount,
                2,
                address(this)
            );
        } else {
            IERC20(_asset).safeIncreaseAllowance(address(_lendingPool), _repayAmount);
            _lendingPool.repay(_asset, _repayAmount, 2, address(this));
        }
    }
}
