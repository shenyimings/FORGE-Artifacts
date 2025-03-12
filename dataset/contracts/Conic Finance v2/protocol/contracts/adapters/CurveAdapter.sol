// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../interfaces/IPoolAdapter.sol";
import "../../interfaces/IController.sol";
import "../../interfaces/IConvexHandler.sol";
import "../../interfaces/ICurveHandler.sol";
import "../../interfaces/vendor/IBaseRewardPool.sol";

import "../../libraries/ScaledMath.sol";

contract CurveAdapter is IPoolAdapter {
    using Address for address;
    using ScaledMath for uint256;

    IController public immutable controller;

    constructor(IController _controller) {
        controller = _controller;
    }

    function deposit(
        address curvePool,
        address underlying,
        uint256 underlyingAmount
    ) external override {
        if (underlyingAmount == 0) return;

        controller.curveHandler().functionDelegateCall(
            abi.encodeWithSignature(
                "deposit(address,address,uint256)",
                curvePool,
                underlying,
                underlyingAmount
            )
        );

        uint256 depositAmount = _getDepositAmount(address(this), curvePool);
        if (depositAmount > 0) {
            controller.convexHandler().functionDelegateCall(
                abi.encodeWithSignature("deposit(address,uint256)", curvePool, depositAmount)
            );
        }
    }

    function withdraw(
        address pool,
        address underlying,
        uint256 underlyingAmount
    ) external override {
        ICurveRegistryCache registryCache = controller.curveRegistryCache();
        address curveLpToken = registryCache.lpToken(pool);

        uint256 lpToWithdraw = controller.priceOracle().underlyingToCurveLp(
            underlying,
            curveLpToken,
            underlyingAmount
        );
        if (lpToWithdraw == 0) return;

        uint256 totalAvailableLp = _totalCurveLpBalance(address(this), pool);

        uint256 idleCurveLpBalance = _idleCurveLpBalance(address(this), pool);

        // Due to rounding errors with the conversion of underlying to LP tokens,
        // we may not have the precise amount of LP tokens to withdraw from the pool.
        // In this case, we withdraw the maximum amount of LP tokens available.
        if (totalAvailableLp < lpToWithdraw) {
            lpToWithdraw = totalAvailableLp;
        }

        if (lpToWithdraw > idleCurveLpBalance) {
            controller.convexHandler().functionDelegateCall(
                abi.encodeWithSignature(
                    "withdraw(address,uint256)",
                    pool,
                    lpToWithdraw - idleCurveLpBalance
                )
            );
        }

        controller.curveHandler().functionDelegateCall(
            abi.encodeWithSignature(
                "withdraw(address,address,uint256)",
                pool,
                underlying,
                lpToWithdraw
            )
        );
    }

    function computePoolValueInUnderlying(
        address conicPool,
        address pool,
        address underlying,
        uint256 underlyingPrice
    ) external view override returns (uint256 underlyingAmount) {
        uint8 decimals = IERC20Metadata(underlying).decimals();
        uint256 usdAmount = computePoolValueInUSD(conicPool, pool);
        underlyingAmount = usdAmount.convertScale(18, decimals).divDown(underlyingPrice);
    }

    function computePoolValueInUSD(
        address conicPool,
        address pool
    ) public view override returns (uint256 usdAmount) {
        IGenericOracle priceOracle = controller.priceOracle();
        address curveLpToken = controller.curveRegistryCache().lpToken(pool);
        uint8 lpDecimals = IERC20Metadata(curveLpToken).decimals();
        uint256 lpBalance = _totalCurveLpBalance(conicPool, pool);
        uint256 lpPrice = priceOracle.getUSDPrice(curveLpToken);
        usdAmount = lpBalance.convertScale(lpDecimals, 18).mulDown(lpPrice);
    }

    function _getDepositAmount(
        address conicPool,
        address curvePool
    ) internal view returns (uint256) {
        uint256 maxIdleCurveLpRatio = IConicPool(conicPool).maxIdleCurveLpRatio();
        uint256 idleCurveLpBalance = _idleCurveLpBalance(conicPool, curvePool);
        uint256 totalCurveLpBalance = _stakedCurveLpBalance(conicPool, curvePool) +
            idleCurveLpBalance;

        if (idleCurveLpBalance.divDown(totalCurveLpBalance) >= maxIdleCurveLpRatio) {
            return idleCurveLpBalance;
        }
        return 0;
    }

    function _idleCurveLpBalance(
        address conicPool_,
        address curvePool_
    ) internal view returns (uint256) {
        return IERC20(controller.curveRegistryCache().lpToken(curvePool_)).balanceOf(conicPool_);
    }

    function _stakedCurveLpBalance(
        address conicPool_,
        address curvePool_
    ) internal view returns (uint256) {
        address rewardPool = IConvexHandler(controller.convexHandler()).getRewardPool(curvePool_);
        return IBaseRewardPool(rewardPool).balanceOf(conicPool_);
    }

    function _totalCurveLpBalance(
        address conicPool_,
        address curvePool_
    ) internal view returns (uint256) {
        return
            _stakedCurveLpBalance(conicPool_, curvePool_) +
            _idleCurveLpBalance(conicPool_, curvePool_);
    }

    function claimEarnings(address conicPool, address pool) external override {
        IConvexHandler(controller.convexHandler()).claimEarnings(pool, conicPool);
    }

    function lpToken(address pool) external view override returns (address) {
        return controller.curveRegistryCache().lpToken(pool);
    }

    function supportsAsset(address pool, address asset) external view override returns (bool) {
        return controller.curveRegistryCache().hasCoinAnywhere(pool, asset);
    }

    function getCRVEarnedOnConvex(
        address account,
        address curvePool
    ) external view override returns (uint256) {
        return IConvexHandler(controller.convexHandler()).getCrvEarned(account, curvePool);
    }

    function executeSanityCheck(address pool) external override {
        ICurveHandler(controller.curveHandler()).reentrancyCheck(pool);
    }
}
