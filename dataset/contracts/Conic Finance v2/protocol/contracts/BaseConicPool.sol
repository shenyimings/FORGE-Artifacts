// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../interfaces/pools/IConicPool.sol";
import "../interfaces/pools/IRewardManager.sol";
import "../interfaces/pools/IWithdrawalProcessor.sol";
import "../interfaces/ICurveRegistryCache.sol";
import "../interfaces/tokenomics/IInflationManager.sol";
import "../interfaces/tokenomics/ILpTokenStaker.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/vendor/IBaseRewardPool.sol";

import "./LpToken.sol";
import "./Pausable.sol";

import "../libraries/ScaledMath.sol";
import "../libraries/ArrayExtensions.sol";

abstract contract BaseConicPool is IConicPool, Pausable {
    using ArrayExtensions for uint256[];
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for ILpToken;
    using ScaledMath for uint256;
    using Address for address;
    using ERC165Checker for address;

    // Avoid stack depth errors
    struct DepositVars {
        uint256 exchangeRate;
        uint256 underlyingBalanceIncrease;
        uint256 mintableUnderlyingAmount;
        uint256 lpReceived;
        uint256 underlyingBalanceBefore;
        uint256 allocatedBalanceBefore;
        uint256[] allocatedPerPoolBefore;
        uint256 underlyingBalanceAfter;
        uint256 allocatedBalanceAfter;
        uint256[] allocatedPerPoolAfter;
    }

    uint256 internal constant _IDLE_RATIO_UPPER_BOUND = 0.2e18;
    uint256 internal constant _MIN_DEPEG_THRESHOLD = 0.01e18;
    uint256 internal constant _MAX_DEPEG_THRESHOLD = 0.1e18;
    uint256 internal constant _MAX_DEVIATION_UPPER_BOUND = 0.2e18;
    uint256 internal constant _TOTAL_UNDERLYING_CACHE_EXPIRY = 3 days;
    uint256 internal constant _MAX_USD_VALUE_FOR_REMOVING_POOL = 100e18;

    IERC20 internal immutable CVX;
    IERC20 internal immutable CRV;
    IERC20 internal constant CNC = IERC20(0x9aE380F0272E2162340a5bB646c354271c0F5cFC);
    address internal constant _WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IERC20Metadata public immutable override underlying;
    ILpToken public immutable override lpToken;

    IRewardManager public immutable rewardManager;

    /// @dev once the deviation gets under this threshold, the reward distribution will be paused
    /// until the next rebalancing. This is expressed as a ratio, scaled with 18 decimals
    uint256 public maxDeviation = 0.02e18; // 2%
    uint256 public maxIdleCurveLpRatio = 0.05e18; // triggers Convex staking when exceeded
    bool public isShutdown;
    uint256 public depegThreshold = 0.03e18; // 3%
    uint256 internal _cacheUpdatedTimestamp;
    uint256 internal _cachedTotalUnderlying;

    /// @dev `true` while the reward distribution is active
    bool public rebalancingRewardActive;

    EnumerableSet.AddressSet internal _pools;
    EnumerableMap.AddressToUintMap internal weights; // liquidity allocation weights

    /// @dev the absolute value in terms of USD of the total deviation after
    /// the weights have been updated
    uint256 public totalDeviationAfterWeightUpdate;

    mapping(address => uint256) _cachedPrices;

    modifier onlyController() {
        require(msg.sender == address(controller), "not authorized");
        _;
    }

    constructor(
        address _underlying,
        IRewardManager _rewardManager,
        address _controller,
        string memory _lpTokenName,
        string memory _symbol,
        address _cvx,
        address _crv
    ) Pausable(IController(_controller)) {
        require(
            _underlying != _cvx && _underlying != _crv && _underlying != address(CNC),
            "invalid underlying"
        );
        underlying = IERC20Metadata(_underlying);
        uint8 decimals = IERC20Metadata(_underlying).decimals();
        lpToken = new LpToken(_controller, address(this), decimals, _lpTokenName, _symbol);
        rewardManager = _rewardManager;

        CVX = IERC20(_cvx);
        CRV = IERC20(_crv);
        CVX.safeApprove(address(_rewardManager), type(uint256).max);
        CRV.safeApprove(address(_rewardManager), type(uint256).max);
        CNC.safeApprove(address(_rewardManager), type(uint256).max);
    }

    /// @dev We always delegate-call to the Curve handler, which means
    /// that we need to be able to receive the ETH to unwrap it and
    /// send it to the Curve pool, as well as to receive it back from
    /// the Curve pool when withdrawing
    receive() external payable {
        require(address(underlying) == _WETH_ADDRESS, "not WETH pool");
    }

    /// @notice Deposit underlying on behalf of someone
    /// @param underlyingAmount Amount of underlying to deposit
    /// @param minLpReceived The minimum amount of LP to accept from the deposit
    /// @return lpReceived The amount of LP received
    function depositFor(
        address account,
        uint256 underlyingAmount,
        uint256 minLpReceived,
        bool stake
    ) public override notPaused returns (uint256) {
        _sanityChecks();

        DepositVars memory vars;

        // Preparing deposit
        require(!isShutdown, "pool is shutdown");
        require(underlyingAmount > 0, "deposit amount cannot be zero");
        uint256 underlyingPrice_ = controller.priceOracle().getUSDPrice(address(underlying));
        (
            vars.underlyingBalanceBefore,
            vars.allocatedBalanceBefore,
            vars.allocatedPerPoolBefore
        ) = _getTotalAndPerPoolUnderlying(underlyingPrice_);
        vars.exchangeRate = _exchangeRate(vars.underlyingBalanceBefore);

        // Executing deposit
        underlying.safeTransferFrom(msg.sender, address(this), underlyingAmount);
        _depositToCurve(
            vars.allocatedBalanceBefore,
            vars.allocatedPerPoolBefore,
            underlying.balanceOf(address(this))
        );

        // Minting LP Tokens
        (
            vars.underlyingBalanceAfter,
            vars.allocatedBalanceAfter,
            vars.allocatedPerPoolAfter
        ) = _getTotalAndPerPoolUnderlying(underlyingPrice_);
        vars.underlyingBalanceIncrease = vars.underlyingBalanceAfter - vars.underlyingBalanceBefore;
        vars.mintableUnderlyingAmount = _min(underlyingAmount, vars.underlyingBalanceIncrease);
        vars.lpReceived = vars.mintableUnderlyingAmount.divDown(vars.exchangeRate);
        require(vars.lpReceived >= minLpReceived, "too much slippage");

        if (stake) {
            lpToken.mint(address(this), vars.lpReceived, account);
            ILpTokenStaker lpTokenStaker = controller.lpTokenStaker();
            lpToken.safeApprove(address(lpTokenStaker), vars.lpReceived);
            lpTokenStaker.stakeFor(vars.lpReceived, address(this), account);
        } else {
            lpToken.mint(account, vars.lpReceived, account);
        }

        _handleRebalancingRewards(
            account,
            vars.allocatedBalanceBefore,
            vars.allocatedPerPoolBefore,
            vars.allocatedBalanceAfter,
            vars.allocatedPerPoolAfter
        );

        _cachedTotalUnderlying = vars.underlyingBalanceAfter;
        _cacheUpdatedTimestamp = block.timestamp;

        emit Deposit(msg.sender, account, underlyingAmount, vars.lpReceived);
        return vars.lpReceived;
    }

    /// @notice Deposit underlying
    /// @param underlyingAmount Amount of underlying to deposit
    /// @param minLpReceived The minimum amoun of LP to accept from the deposit
    /// @return lpReceived The amount of LP received
    function deposit(
        uint256 underlyingAmount,
        uint256 minLpReceived
    ) external override returns (uint256) {
        return depositFor(msg.sender, underlyingAmount, minLpReceived, true);
    }

    /// @notice Deposit underlying
    /// @param underlyingAmount Amount of underlying to deposit
    /// @param minLpReceived The minimum amoun of LP to accept from the deposit
    /// @param stake Whether or not to stake in the LpTokenStaker
    /// @return lpReceived The amount of LP received
    function deposit(
        uint256 underlyingAmount,
        uint256 minLpReceived,
        bool stake
    ) external override returns (uint256) {
        return depositFor(msg.sender, underlyingAmount, minLpReceived, stake);
    }

    function _depositToCurve(
        uint256 totalUnderlying_,
        uint256[] memory allocatedPerPool,
        uint256 underlyingAmount_
    ) internal {
        uint256 depositsRemaining_ = underlyingAmount_;
        uint256 totalAfterDeposit_ = totalUnderlying_ + underlyingAmount_;

        // NOTE: avoid modifying `allocatedPerPool`
        uint256[] memory allocatedPerPoolCopy = allocatedPerPool.copy();

        while (depositsRemaining_ > 0) {
            (uint256 poolIndex_, uint256 maxDeposit_) = _getDepositPool(
                totalAfterDeposit_,
                allocatedPerPoolCopy
            );
            // account for rounding errors
            if (depositsRemaining_ < maxDeposit_ + 1e2) {
                maxDeposit_ = depositsRemaining_;
            }

            address pool_ = _pools.at(poolIndex_);

            // Depositing into least balanced pool
            uint256 toDeposit_ = _min(depositsRemaining_, maxDeposit_);
            address poolAdapter = address(controller.poolAdapterFor(pool_));
            poolAdapter.functionDelegateCall(
                abi.encodeWithSignature(
                    "deposit(address,address,uint256)",
                    pool_,
                    address(underlying),
                    toDeposit_
                )
            );

            depositsRemaining_ -= toDeposit_;
            allocatedPerPoolCopy[poolIndex_] += toDeposit_;
        }
    }

    function _getDepositPool(
        uint256 totalUnderlying_,
        uint256[] memory allocatedPerPool
    ) internal view returns (uint256 poolIndex, uint256 maxDepositAmount) {
        uint256 poolsCount_ = allocatedPerPool.length;
        int256 iPoolIndex = -1;
        for (uint256 i; i < poolsCount_; i++) {
            address pool_ = _pools.at(i);
            uint256 allocatedUnderlying_ = allocatedPerPool[i];
            uint256 targetAllocation_ = totalUnderlying_.mulDown(weights.get(pool_));
            if (allocatedUnderlying_ >= targetAllocation_) continue;
            uint256 maxBalance_ = targetAllocation_ + targetAllocation_.mulDown(_getMaxDeviation());
            uint256 maxDepositAmount_ = maxBalance_ - allocatedUnderlying_;
            if (maxDepositAmount_ <= maxDepositAmount) continue;
            maxDepositAmount = maxDepositAmount_;
            iPoolIndex = int256(i);
        }
        require(iPoolIndex > -1, "error retrieving deposit pool");
        poolIndex = uint256(iPoolIndex);
    }

    /// @notice Get current underlying balance of pool
    function totalUnderlying() public view virtual returns (uint256) {
        (uint256 totalUnderlying_, , ) = getTotalAndPerPoolUnderlying();

        return totalUnderlying_;
    }

    function _exchangeRate(uint256 totalUnderlying_) internal view returns (uint256) {
        uint256 lpSupply = lpToken.totalSupply();
        if (lpSupply == 0 || totalUnderlying_ == 0) return ScaledMath.ONE;

        return totalUnderlying_.divDown(lpSupply);
    }

    /// @notice Get current exchange rate for the pool's LP token to the underlying
    function exchangeRate() public view virtual override returns (uint256) {
        return _exchangeRate(totalUnderlying());
    }

    /// @notice Get current exchange rate for the pool's LP token to USD
    /// @dev This is using the cached total underlying value, so is not precisely accurate.
    function usdExchangeRate() external view virtual override returns (uint256) {
        uint256 underlyingPrice = controller.priceOracle().getUSDPrice(address(underlying));
        return _exchangeRate(_cachedTotalUnderlying).mulDown(underlyingPrice);
    }

    /// @notice Unstake LP Tokens and withdraw underlying
    /// @param conicLpAmount Amount of LP tokens to burn
    /// @param minUnderlyingReceived Minimum amount of underlying to redeem
    /// This should always be set to a reasonable value (e.g. 2%), otherwise
    /// the user withdrawing could be forced into paying a withdrawal penalty fee
    /// by another user
    /// @return uint256 Total underlying withdrawn
    function unstakeAndWithdraw(
        uint256 conicLpAmount,
        uint256 minUnderlyingReceived,
        address to
    ) public override returns (uint256) {
        controller.lpTokenStaker().unstakeFrom(conicLpAmount, msg.sender);
        return withdraw(conicLpAmount, minUnderlyingReceived, to);
    }

    function unstakeAndWithdraw(
        uint256 conicLpAmount,
        uint256 minUnderlyingReceived
    ) external returns (uint256) {
        return unstakeAndWithdraw(conicLpAmount, minUnderlyingReceived, msg.sender);
    }

    function withdraw(
        uint256 conicLpAmount,
        uint256 minUnderlyingReceived
    ) public override returns (uint256) {
        return withdraw(conicLpAmount, minUnderlyingReceived, msg.sender);
    }

    /// @notice Withdraw underlying
    /// @param conicLpAmount Amount of LP tokens to burn
    /// @param minUnderlyingReceived Minimum amount of underlying to redeem
    /// This should always be set to a reasonable value (e.g. 2%), otherwise
    /// the user withdrawing could be forced into paying a withdrawal penalty fee
    /// by another user
    /// @return uint256 Total underlying withdrawn
    function withdraw(
        uint256 conicLpAmount,
        uint256 minUnderlyingReceived,
        address to
    ) public override returns (uint256) {
        _sanityChecks();

        // Preparing Withdrawals
        require(lpToken.balanceOf(msg.sender) >= conicLpAmount, "insufficient balance");
        uint256 underlyingBalanceBefore_ = underlying.balanceOf(address(this));

        // Processing Withdrawals
        (
            uint256 totalUnderlying_,
            uint256 allocatedUnderlying_,
            uint256[] memory allocatedPerPool
        ) = getTotalAndPerPoolUnderlying();
        uint256 underlyingToReceive_ = conicLpAmount.mulDown(_exchangeRate(totalUnderlying_));
        {
            if (underlyingBalanceBefore_ < underlyingToReceive_) {
                uint256 underlyingToWithdraw_ = underlyingToReceive_ - underlyingBalanceBefore_;
                _withdrawFromCurve(allocatedUnderlying_, allocatedPerPool, underlyingToWithdraw_);
            }
        }

        // Sending Underlying and burning LP Tokens
        uint256 underlyingWithdrawn_ = _min(
            underlying.balanceOf(address(this)),
            underlyingToReceive_
        );
        require(underlyingWithdrawn_ >= minUnderlyingReceived, "too much slippage");
        lpToken.burn(msg.sender, conicLpAmount, msg.sender);
        underlying.safeTransfer(to, underlyingWithdrawn_);

        _cachedTotalUnderlying = totalUnderlying_ - underlyingWithdrawn_;
        _cacheUpdatedTimestamp = block.timestamp;

        // state has already been updated, so no need to worry about re-entrancy
        if (to.supportsInterface(type(IWithdrawalProcessor).interfaceId)) {
            IWithdrawalProcessor(to).processWithdrawal(msg.sender, underlyingWithdrawn_);
        }

        emit Withdraw(msg.sender, underlyingWithdrawn_);
        return underlyingWithdrawn_;
    }

    function _withdrawFromCurve(
        uint256 totalUnderlying_,
        uint256[] memory allocatedPerPool,
        uint256 amount_
    ) internal {
        uint256 withdrawalsRemaining_ = amount_;
        uint256 totalAfterWithdrawal_ = totalUnderlying_ - amount_;

        // NOTE: avoid modifying `allocatedPerPool`
        uint256[] memory allocatedPerPoolCopy = allocatedPerPool.copy();

        while (withdrawalsRemaining_ > 0) {
            (uint256 poolIndex_, uint256 maxWithdrawal_) = _getWithdrawPool(
                totalAfterWithdrawal_,
                allocatedPerPoolCopy
            );
            address pool_ = _pools.at(poolIndex_);

            // Withdrawing from least balanced pool
            uint256 toWithdraw_ = _min(withdrawalsRemaining_, maxWithdrawal_);

            address poolAdapter = address(controller.poolAdapterFor(pool_));
            poolAdapter.functionDelegateCall(
                abi.encodeWithSignature(
                    "withdraw(address,address,uint256)",
                    pool_,
                    underlying,
                    toWithdraw_
                )
            );
            withdrawalsRemaining_ -= toWithdraw_;
            allocatedPerPoolCopy[poolIndex_] -= toWithdraw_;
        }
    }

    function _getWithdrawPool(
        uint256 totalUnderlying_,
        uint256[] memory allocatedPerPool
    ) internal view returns (uint256 withdrawPoolIndex, uint256 maxWithdrawalAmount) {
        uint256 poolsCount_ = allocatedPerPool.length;
        int256 iWithdrawPoolIndex = -1;
        for (uint256 i; i < poolsCount_; i++) {
            address curvePool_ = _pools.at(i);
            uint256 weight_ = weights.get(curvePool_);
            uint256 allocatedUnderlying_ = allocatedPerPool[i];

            // If a pool has a weight of 0,
            // withdraw from it if it has more than the max lp value
            if (weight_ == 0) {
                uint256 price_ = controller.priceOracle().getUSDPrice(address(underlying));
                uint256 allocatedUsd = (price_ * allocatedUnderlying_) /
                    10 ** underlying.decimals();
                if (allocatedUsd >= _MAX_USD_VALUE_FOR_REMOVING_POOL / 2) {
                    return (uint256(i), allocatedUnderlying_);
                }
            }

            uint256 targetAllocation_ = totalUnderlying_.mulDown(weight_);
            if (allocatedUnderlying_ <= targetAllocation_) continue;
            uint256 minBalance_ = targetAllocation_ - targetAllocation_.mulDown(_getMaxDeviation());
            uint256 maxWithdrawalAmount_ = allocatedUnderlying_ - minBalance_;
            if (maxWithdrawalAmount_ <= maxWithdrawalAmount) continue;
            maxWithdrawalAmount = maxWithdrawalAmount_;
            iWithdrawPoolIndex = int256(i);
        }
        require(iWithdrawPoolIndex > -1, "error retrieving withdraw pool");
        withdrawPoolIndex = uint256(iWithdrawPoolIndex);
    }

    function allPools() external view override returns (address[] memory) {
        return _pools.values();
    }

    function poolsCount() external view override returns (uint256) {
        return _pools.length();
    }

    function getPoolAtIndex(uint256 _index) external view returns (address) {
        return _pools.at(_index);
    }

    function isRegisteredPool(address _pool) public view returns (bool) {
        return _pools.contains(_pool);
    }

    function getPoolWeight(address _pool) external view returns (uint256) {
        (, uint256 _weight) = weights.tryGet(_pool);
        return _weight;
    }

    // Controller and Admin functions

    function addPool(address _pool) external override onlyOwner {
        require(!_pools.contains(_pool), "pool already added");
        IPoolAdapter poolAdapter = controller.poolAdapterFor(_pool);
        bool supported_ = poolAdapter.supportsAsset(_pool, address(underlying));
        require(supported_, "coin not in pool");
        address lpToken_ = poolAdapter.lpToken(_pool);
        require(controller.priceOracle().isTokenSupported(lpToken_), "cannot price LP Token");

        address booster = controller.convexBooster();
        IERC20(lpToken_).safeApprove(booster, type(uint256).max);

        if (!weights.contains(_pool)) weights.set(_pool, 0);
        require(_pools.add(_pool), "failed to add pool");
        emit CurvePoolAdded(_pool);
    }

    // This requires that the weight of the pool is first set to 0
    function removePool(address _pool) external override onlyOwner {
        require(_pools.contains(_pool), "pool not added");
        require(_pools.length() > 1, "cannot remove last pool");
        IPoolAdapter poolAdapter = controller.poolAdapterFor(_pool);
        address lpToken_ = poolAdapter.lpToken(_pool);
        uint256 usdValue = poolAdapter.computePoolValueInUSD(address(this), _pool);
        require(usdValue < _MAX_USD_VALUE_FOR_REMOVING_POOL, "pool has allocated funds");
        uint256 weight = weights.get(_pool);
        IERC20(lpToken_).safeApprove(controller.convexBooster(), 0);
        require(weight == 0, "pool has weight set");
        require(_pools.remove(_pool), "pool not removed");
        require(weights.remove(_pool), "weight not removed");
        emit CurvePoolRemoved(_pool);
    }

    function updateWeights(PoolWeight[] memory poolWeights) external onlyController {
        require(poolWeights.length == _pools.length(), "invalid pool weights");
        uint256 total;
        for (uint256 i; i < poolWeights.length; i++) {
            address pool = poolWeights[i].poolAddress;
            require(isRegisteredPool(pool), "pool is not registered");
            uint256 newWeight = poolWeights[i].weight;
            weights.set(pool, newWeight);
            emit NewWeight(pool, newWeight);
            total += newWeight;
        }

        require(total == ScaledMath.ONE, "weights do not sum to 1");

        (
            uint256 totalUnderlying_,
            uint256 totalAllocated,
            uint256[] memory allocatedPerPool
        ) = getTotalAndPerPoolUnderlying();

        uint256 totalDeviation = _computeTotalDeviation(totalUnderlying_, allocatedPerPool);
        totalDeviationAfterWeightUpdate = totalDeviation;
        rebalancingRewardActive = !_isBalanced(allocatedPerPool, totalAllocated);

        // Updating price cache for all pools
        // Used for seeing if a pool has depegged
        _updatePriceCache();
    }

    function shutdownPool() external override onlyController {
        require(!isShutdown, "pool already shutdown");
        isShutdown = true;
        emit Shutdown();
    }

    function updateDepegThreshold(uint256 newDepegThreshold_) external onlyOwner {
        require(newDepegThreshold_ >= _MIN_DEPEG_THRESHOLD, "invalid depeg threshold");
        require(newDepegThreshold_ <= _MAX_DEPEG_THRESHOLD, "invalid depeg threshold");
        depegThreshold = newDepegThreshold_;
        emit DepegThresholdUpdated(newDepegThreshold_);
    }

    /// @notice Called when an underlying of a Curve Pool has depegged and we want to exit the pool.
    /// Will check if a coin has depegged, and will revert if not.
    /// Sets the weight of the Curve Pool to 0, and re-enables CNC rewards for deposits.
    /// @dev Cannot be called if the underlying of this pool itself has depegged.
    /// @param curvePool_ The Curve Pool to handle.
    function handleDepeggedCurvePool(address curvePool_) external override {
        _sanityChecks();

        // Validation
        require(isRegisteredPool(curvePool_), "pool is not registered");
        require(weights.get(curvePool_) != 0, "pool weight already 0");
        require(!_isDepegged(address(underlying)), "underlying is depegged");
        address lpToken_ = controller.poolAdapterFor(curvePool_).lpToken(curvePool_);
        require(_isDepegged(lpToken_), "pool is not depegged");

        // Set target curve pool weight to 0
        // Scale up other weights to compensate
        _setWeightToZero(curvePool_);
        rebalancingRewardActive = true;

        emit HandledDepeggedCurvePool(curvePool_);
    }

    function _setWeightToZero(address zeroedPool) internal {
        uint256 weight_ = weights.get(zeroedPool);
        if (weight_ == 0) return;
        require(weight_ != ScaledMath.ONE, "can't remove last pool");
        uint256 scaleUp_ = ScaledMath.ONE.divDown(ScaledMath.ONE - weights.get(zeroedPool));
        uint256 curvePoolLength_ = _pools.length();
        for (uint256 i; i < curvePoolLength_; i++) {
            address pool_ = _pools.at(i);
            uint256 newWeight_ = pool_ == zeroedPool ? 0 : weights.get(pool_).mulDown(scaleUp_);
            weights.set(pool_, newWeight_);
            emit NewWeight(pool_, newWeight_);
        }

        // Updating total deviation
        (
            uint256 totalUnderlying_,
            ,
            uint256[] memory allocatedPerPool
        ) = getTotalAndPerPoolUnderlying();
        uint256 totalDeviation = _computeTotalDeviation(totalUnderlying_, allocatedPerPool);
        totalDeviationAfterWeightUpdate = totalDeviation;
    }

    /**
     * @notice Allows anyone to set the weight of a Curve pool to 0 if the Convex pool for the
     * associated PID has been shutdown. This is a very unilkely outcomu and the method does
     * not reenable rebalancing rewards.
     * @param curvePool_ Curve pool for which the Convex PID is invalid (has been shut down)
     */
    function handleInvalidConvexPid(address curvePool_) external {
        require(isRegisteredPool(curvePool_), "curve pool not registered");
        ICurveRegistryCache registryCache_ = controller.curveRegistryCache();
        uint256 pid = registryCache_.getPid(curvePool_);
        require(registryCache_.isShutdownPid(pid), "convex pool pid is shutdown");
        _setWeightToZero(curvePool_);
        emit HandledInvalidConvexPid(curvePool_, pid);
    }

    function setMaxIdleCurveLpRatio(uint256 maxIdleCurveLpRatio_) external onlyOwner {
        require(maxIdleCurveLpRatio != maxIdleCurveLpRatio_, "same as current");
        require(maxIdleCurveLpRatio_ <= _IDLE_RATIO_UPPER_BOUND, "ratio exceeds upper bound");
        maxIdleCurveLpRatio = maxIdleCurveLpRatio_;
        emit NewMaxIdleCurveLpRatio(maxIdleCurveLpRatio_);
    }

    function setMaxDeviation(uint256 maxDeviation_) external onlyOwner {
        require(maxDeviation != maxDeviation_, "same as current");
        require(maxDeviation_ <= _MAX_DEVIATION_UPPER_BOUND, "deviation exceeds upper bound");
        maxDeviation = maxDeviation_;
        emit MaxDeviationUpdated(maxDeviation_);
    }

    function getWeight(address pool) external view returns (uint256) {
        return weights.get(pool);
    }

    function getWeights() external view override returns (PoolWeight[] memory) {
        uint256 length_ = _pools.length();
        PoolWeight[] memory weights_ = new PoolWeight[](length_);
        for (uint256 i; i < length_; i++) {
            (address pool_, uint256 weight_) = weights.at(i);
            weights_[i] = PoolWeight(pool_, weight_);
        }
        return weights_;
    }

    function getAllocatedUnderlying() external view override returns (PoolWithAmount[] memory) {
        PoolWithAmount[] memory perPoolAllocated = new PoolWithAmount[](_pools.length());
        (, , uint256[] memory allocated) = getTotalAndPerPoolUnderlying();

        for (uint256 i; i < perPoolAllocated.length; i++) {
            perPoolAllocated[i] = PoolWithAmount(_pools.at(i), allocated[i]);
        }
        return perPoolAllocated;
    }

    function computeTotalDeviation() external view override returns (uint256) {
        (
            ,
            uint256 allocatedUnderlying_,
            uint256[] memory perPoolUnderlying
        ) = getTotalAndPerPoolUnderlying();
        return _computeTotalDeviation(allocatedUnderlying_, perPoolUnderlying);
    }

    function cachedTotalUnderlying() external view virtual override returns (uint256) {
        if (block.timestamp > _cacheUpdatedTimestamp + _TOTAL_UNDERLYING_CACHE_EXPIRY) {
            return totalUnderlying();
        }
        return _cachedTotalUnderlying;
    }

    function getTotalAndPerPoolUnderlying()
        public
        view
        returns (
            uint256 totalUnderlying_,
            uint256 totalAllocated_,
            uint256[] memory perPoolUnderlying_
        )
    {
        uint256 underlyingPrice_ = controller.priceOracle().getUSDPrice(address(underlying));
        return _getTotalAndPerPoolUnderlying(underlyingPrice_);
    }

    function isBalanced() external view override returns (bool) {
        (
            ,
            uint256 allocatedUnderlying_,
            uint256[] memory allocatedPerPool_
        ) = getTotalAndPerPoolUnderlying();
        return _isBalanced(allocatedPerPool_, allocatedUnderlying_);
    }

    /**
     * @notice Returns several values related to the Omnipools's underlying assets.
     * @param underlyingPrice_ Price of the underlying asset in USD
     * @return totalUnderlying_ Total underlying value of the Omnipool
     * @return totalAllocated_ Total underlying value of the Omnipool that is allocated to Curve pools
     * @return perPoolUnderlying_ Array of underlying values of the Omnipool that is allocated to each Curve pool
     */
    function _getTotalAndPerPoolUnderlying(
        uint256 underlyingPrice_
    )
        internal
        view
        returns (
            uint256 totalUnderlying_,
            uint256 totalAllocated_,
            uint256[] memory perPoolUnderlying_
        )
    {
        uint256 poolsLength_ = _pools.length();
        perPoolUnderlying_ = new uint256[](poolsLength_);

        for (uint256 i; i < poolsLength_; i++) {
            address pool_ = _pools.at(i);
            uint256 poolUnderlying_ = controller.poolAdapterFor(pool_).computePoolValueInUnderlying(
                address(this),
                pool_,
                address(underlying),
                underlyingPrice_
            );
            perPoolUnderlying_[i] = poolUnderlying_;
            totalAllocated_ += poolUnderlying_;
        }
        totalUnderlying_ = totalAllocated_ + underlying.balanceOf(address(this));
    }

    function _computeTotalDeviation(
        uint256 allocatedUnderlying_,
        uint256[] memory perPoolAllocations_
    ) internal view returns (uint256) {
        uint256 totalDeviation;
        for (uint256 i; i < perPoolAllocations_.length; i++) {
            uint256 weight = weights.get(_pools.at(i));
            uint256 targetAmount = allocatedUnderlying_.mulDown(weight);
            totalDeviation += targetAmount.absSub(perPoolAllocations_[i]);
        }
        return totalDeviation;
    }

    function _handleRebalancingRewards(
        address account,
        uint256 allocatedBalanceBefore_,
        uint256[] memory allocatedPerPoolBefore,
        uint256 allocatedBalanceAfter_,
        uint256[] memory allocatedPerPoolAfter
    ) internal {
        if (!rebalancingRewardActive) return;
        uint256 deviationBefore = _computeTotalDeviation(
            allocatedBalanceBefore_,
            allocatedPerPoolBefore
        );
        uint256 deviationAfter = _computeTotalDeviation(
            allocatedBalanceAfter_,
            allocatedPerPoolAfter
        );

        controller.inflationManager().handleRebalancingRewards(
            account,
            deviationBefore,
            deviationAfter
        );

        if (_isBalanced(allocatedPerPoolAfter, allocatedBalanceAfter_)) {
            rebalancingRewardActive = false;
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _isBalanced(
        uint256[] memory allocatedPerPool_,
        uint256 totalAllocated_
    ) internal view returns (bool) {
        if (totalAllocated_ == 0) return true;
        for (uint256 i; i < allocatedPerPool_.length; i++) {
            uint256 weight_ = weights.get(_pools.at(i));
            uint256 currentAllocated_ = allocatedPerPool_[i];

            // If a curve pool has a weight of 0,
            if (weight_ == 0) {
                uint256 price_ = controller.priceOracle().getUSDPrice(address(underlying));
                uint256 allocatedUsd_ = (price_ * currentAllocated_) / 10 ** underlying.decimals();
                if (allocatedUsd_ >= _MAX_USD_VALUE_FOR_REMOVING_POOL / 2) {
                    return false;
                }
                continue;
            }

            uint256 targetAmount = totalAllocated_.mulDown(weight_);
            uint256 deviation = targetAmount.absSub(currentAllocated_);
            uint256 deviationRatio = deviation.divDown(targetAmount);

            if (deviationRatio > maxDeviation) return false;
        }
        return true;
    }

    function _getMaxDeviation() internal view returns (uint256) {
        return rebalancingRewardActive ? 0 : maxDeviation;
    }

    function _sanityChecks() internal virtual {}

    function _updatePriceCache() internal virtual;

    function _isDepegged(address asset_) internal view virtual returns (bool);
}
