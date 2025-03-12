// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./pools/IConicPool.sol";
import "./IGenericOracle.sol";
import "./tokenomics/IInflationManager.sol";
import "./tokenomics/ILpTokenStaker.sol";
import "./IPoolAdapter.sol";
import "./ICurveRegistryCache.sol";

interface IController {
    event PoolAdded(address indexed pool);
    event PoolRemoved(address indexed pool);
    event PoolShutdown(address indexed pool);
    event ConvexBoosterSet(address convexBooster);
    event CurveHandlerSet(address curveHandler);
    event ConvexHandlerSet(address convexHandler);
    event CurveRegistryCacheSet(address curveRegistryCache);
    event InflationManagerSet(address inflationManager);
    event PriceOracleSet(address priceOracle);
    event WeightUpdateMinDelaySet(uint256 weightUpdateMinDelay);
    event PauseManagerSet(address indexed manager, bool isManager);
    event MultiDepositsWithdrawsWhitelistSet(address pool, bool allowed);
    event MinimumTaintedTransferAmountSet(address indexed token, uint256 amount);
    event DefaultPoolAdapterSet(address poolAdapter);
    event CustomPoolAdapterSet(address indexed pool, address poolAdapter);

    struct WeightUpdate {
        address conicPoolAddress;
        IConicPool.PoolWeight[] weights;
    }

    function initialize(address _lpTokenStaker) external;

    // inflation manager

    function inflationManager() external view returns (IInflationManager);

    function setInflationManager(address manager) external;

    // views
    function curveRegistryCache() external view returns (ICurveRegistryCache);

    // pool adapter
    function poolAdapterFor(address pool) external view returns (IPoolAdapter);

    function defaultPoolAdapter() external view returns (IPoolAdapter);

    function setDefaultPoolAdapter(address poolAdapter) external;

    function setCustomPoolAdapter(address pool, address poolAdapter) external;

    /// lp token staker
    function switchLpTokenStaker(address _lpTokenStaker) external;

    function lpTokenStaker() external view returns (ILpTokenStaker);

    // oracle
    function priceOracle() external view returns (IGenericOracle);

    function setPriceOracle(address oracle) external;

    // pool functions

    function listPools() external view returns (address[] memory);

    function listActivePools() external view returns (address[] memory);

    function isPool(address poolAddress) external view returns (bool);

    function isActivePool(address poolAddress) external view returns (bool);

    function addPool(address poolAddress) external;

    function shutdownPool(address poolAddress) external;

    function removePool(address poolAddress) external;

    function cncToken() external view returns (address);

    function lastWeightUpdate(address poolAddress) external view returns (uint256);

    function updateWeights(WeightUpdate memory update) external;

    function updateAllWeights(WeightUpdate[] memory weights) external;

    // handler functions

    function convexBooster() external view returns (address);

    function curveHandler() external view returns (address);

    function convexHandler() external view returns (address);

    function setConvexBooster(address _convexBooster) external;

    function setCurveHandler(address _curveHandler) external;

    function setConvexHandler(address _convexHandler) external;

    function setCurveRegistryCache(address curveRegistryCache_) external;

    function setWeightUpdateMinDelay(uint256 delay) external;

    function isPauseManager(address account) external view returns (bool);

    function listPauseManagers() external view returns (address[] memory);

    function setPauseManager(address account, bool isManager) external;

    // deposit/withdrawal whitelist
    function isAllowedMultipleDepositsWithdraws(address poolAddress) external view returns (bool);

    function setAllowedMultipleDepositsWithdraws(address account, bool allowed) external;

    function getMultipleDepositsWithdrawsWhitelist() external view returns (address[] memory);

    // tainted transfer amount
    function setMinimumTaintedTransferAmount(address token, uint256 amount) external;

    function getMinimumTaintedTransferAmount(address token) external view returns (uint256);
}
