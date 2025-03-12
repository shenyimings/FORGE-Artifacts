// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IController.sol";
import "../interfaces/tokenomics/ILpTokenStaker.sol";
import "../interfaces/IPoolAdapter.sol";
import "../interfaces/vendor/IBooster.sol";

contract Controller is IController, Ownable, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant _MAX_WEIGHT_UPDATE_MIN_DELAY = 32 days;
    uint256 internal constant _MIN_WEIGHT_UPDATE_MIN_DELAY = 1 days;

    EnumerableSet.AddressSet internal _pools;
    EnumerableSet.AddressSet internal _activePools;
    EnumerableSet.AddressSet internal _pauseManagers;
    EnumerableSet.AddressSet internal _multiDepositsWithdrawsWhitelist;

    mapping(address => uint256) internal _minimumTaintedTransferAmount;

    address public immutable cncToken;

    address public override convexBooster = address(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address public override curveHandler;
    address public override convexHandler;
    IGenericOracle public override priceOracle;
    ICurveRegistryCache public override curveRegistryCache;

    IInflationManager public override inflationManager;
    ILpTokenStaker public override lpTokenStaker;

    mapping(address => IPoolAdapter) internal _customPoolAdapters;
    IPoolAdapter public override defaultPoolAdapter;

    uint256 public weightUpdateMinDelay;

    mapping(address => uint256) public lastWeightUpdate;

    constructor(address cncToken_, address curveRegistryCacheAddress_) {
        cncToken = cncToken_;
        curveRegistryCache = ICurveRegistryCache(curveRegistryCacheAddress_);
    }

    function initialize(address _lpTokenStaker) external onlyOwner initializer {
        lpTokenStaker = ILpTokenStaker(_lpTokenStaker);
    }

    /// @notice shut downs the current lp token staker and sets a new one
    function switchLpTokenStaker(address _lpTokenStaker) external onlyOwner {
        lpTokenStaker.shutdown();
        lpTokenStaker = ILpTokenStaker(_lpTokenStaker);
        for (uint256 i; i < _pools.length(); i++) {
            lpTokenStaker.checkpoint(_pools.at(i));
        }
    }

    function listPools() external view override returns (address[] memory) {
        return _pools.values();
    }

    function listActivePools() external view override returns (address[] memory) {
        return _activePools.values();
    }

    function addPool(address poolAddress) external override onlyOwner {
        require(_pools.add(poolAddress), "failed to add pool");
        require(_activePools.add(poolAddress), "failed to add pool");
        lpTokenStaker.checkpoint(poolAddress);
        emit PoolAdded(poolAddress);
    }

    function removePool(address poolAddress) external override onlyOwner {
        require(_pools.remove(poolAddress), "failed to remove pool");
        require(!_activePools.contains(poolAddress), "shutdown the pool before removing it");
        emit PoolRemoved(poolAddress);
    }

    function shutdownPool(address poolAddress) external override onlyOwner {
        require(_activePools.remove(poolAddress), "failed to remove pool");
        IConicPool(poolAddress).shutdownPool();
        inflationManager.updatePoolWeights();
        emit PoolShutdown(poolAddress);
    }

    function isPool(address poolAddress) external view override returns (bool) {
        return _pools.contains(poolAddress);
    }

    function isActivePool(address poolAddress) external view override returns (bool) {
        return _activePools.contains(poolAddress);
    }

    function updateWeights(WeightUpdate memory update) public override onlyOwner {
        require(
            lastWeightUpdate[update.conicPoolAddress] + weightUpdateMinDelay < block.timestamp,
            "weight update delay not elapsed"
        );
        IConicPool(update.conicPoolAddress).updateWeights(update.weights);
        lastWeightUpdate[update.conicPoolAddress] = block.timestamp;
    }

    function updateAllWeights(WeightUpdate[] memory weights) external override onlyOwner {
        for (uint256 i; i < weights.length; i++) {
            updateWeights(weights[i]);
        }
    }

    function setConvexBooster(address _convexBooster) external override onlyOwner {
        require(IBooster(convexBooster).isShutdown(), "current booster is not shutdown");
        convexBooster = _convexBooster;
        emit ConvexBoosterSet(_convexBooster);
    }

    function setCurveHandler(address _curveHandler) external override onlyOwner {
        curveHandler = _curveHandler;
        emit CurveHandlerSet(_curveHandler);
    }

    function setConvexHandler(address _convexHandler) external override onlyOwner {
        convexHandler = _convexHandler;
        emit ConvexHandlerSet(_convexHandler);
    }

    function setInflationManager(address manager) external onlyOwner {
        inflationManager = IInflationManager(manager);
        emit InflationManagerSet(manager);
    }

    function setPriceOracle(address oracle) external override onlyOwner {
        priceOracle = IGenericOracle(oracle);
        emit PriceOracleSet(oracle);
    }

    function setCurveRegistryCache(address curveRegistryCache_) external override onlyOwner {
        curveRegistryCache = ICurveRegistryCache(curveRegistryCache_);
        emit CurveRegistryCacheSet(curveRegistryCache_);
    }

    function poolAdapterFor(address pool) external view override returns (IPoolAdapter) {
        IPoolAdapter adapter = _customPoolAdapters[pool];
        return address(adapter) == address(0) ? defaultPoolAdapter : adapter;
    }

    function setDefaultPoolAdapter(address poolAdapter) external override onlyOwner {
        defaultPoolAdapter = IPoolAdapter(poolAdapter);
        emit DefaultPoolAdapterSet(poolAdapter);
    }

    function setCustomPoolAdapter(address pool, address poolAdapter) external override onlyOwner {
        _customPoolAdapters[pool] = IPoolAdapter(poolAdapter);
        emit CustomPoolAdapterSet(pool, poolAdapter);
    }

    function setWeightUpdateMinDelay(uint256 delay) external override onlyOwner {
        require(delay < _MAX_WEIGHT_UPDATE_MIN_DELAY, "delay too long");
        require(delay > _MIN_WEIGHT_UPDATE_MIN_DELAY, "delay too short");
        weightUpdateMinDelay = delay;
        emit WeightUpdateMinDelaySet(delay);
    }

    function isPauseManager(address account) external view override returns (bool) {
        return _pauseManagers.contains(account);
    }

    function listPauseManagers() external view override returns (address[] memory) {
        return _pauseManagers.values();
    }

    function setPauseManager(address account, bool isManager) external override onlyOwner {
        bool changed = isManager ? _pauseManagers.add(account) : _pauseManagers.remove(account);
        if (changed) emit PauseManagerSet(account, isManager);
    }

    function setAllowedMultipleDepositsWithdraws(address account, bool allowed) external onlyOwner {
        bool changed;
        if (allowed) changed = _multiDepositsWithdrawsWhitelist.add(account);
        else changed = _multiDepositsWithdrawsWhitelist.remove(account);

        if (changed) emit MultiDepositsWithdrawsWhitelistSet(account, allowed);
    }

    function isAllowedMultipleDepositsWithdraws(address account) external view returns (bool) {
        return _multiDepositsWithdrawsWhitelist.contains(account);
    }

    function getMultipleDepositsWithdrawsWhitelist() external view returns (address[] memory) {
        return _multiDepositsWithdrawsWhitelist.values();
    }

    function setMinimumTaintedTransferAmount(
        address token,
        uint256 amount
    ) external override onlyOwner {
        _minimumTaintedTransferAmount[token] = amount;
        emit MinimumTaintedTransferAmountSet(token, amount);
    }

    function getMinimumTaintedTransferAmount(address token) external view returns (uint256) {
        return _minimumTaintedTransferAmount[token];
    }
}
