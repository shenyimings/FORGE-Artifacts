// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../../interfaces/pools/IConicPool.sol";
import "../../interfaces/IController.sol";
import "../../interfaces/tokenomics/IInflationManager.sol";
import "../../interfaces/tokenomics/ILpTokenStaker.sol";
import "../LpToken.sol";
import "../Pausable.sol";

contract MockRewardManager is IRewardManager {
    address public immutable override conicPool;

    constructor(address _pool) {
        conicPool = _pool;
    }

    function accountCheckpoint(address account) external {}

    function poolCheckpoint() external pure returns (bool) {
        return true;
    }

    function addExtraReward(address reward) external returns (bool) {}

    function addBatchExtraRewards(address[] memory rewards) external {}

    function setFeePercentage(
        uint256 // _feePercentage
    ) external pure {
        require(0 == 1, "wrong contract");
    }

    function claimableRewards(
        address account
    ) external view returns (uint256 cncRewards, uint256 crvRewards, uint256 cvxRewards) {}

    function claimEarnings() external returns (uint256, uint256, uint256) {}

    function claimPoolEarnings() external {}

    function sellRewardTokens() external {}

    function claimPoolEarningsAndSellRewardTokens() external {}
}

contract MockPool is IConicPool, Pausable {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap internal weights;
    IRewardManager public immutable rewardManager;
    ILpToken public immutable override lpToken;
    IInflationManager private immutable _inflationManager;

    bool internal _useFakeTotalUnderlying;
    uint256 internal _fakeTotalUnderlying;
    bool public isShutdown;

    IERC20Metadata public override underlying;

    constructor(IController controller_, address _underlying) Pausable(IController(controller_)) {
        underlying = IERC20Metadata(_underlying);
        rewardManager = new MockRewardManager(address(this));
        lpToken = new LpToken(address(controller_), address(this), 18, "TEST", "TEST");
        _inflationManager = controller_.inflationManager();
    }

    function depositFor(
        address _account,
        uint256 _amount,
        uint256 _minLpReceived,
        bool stake
    ) external returns (uint256) {}

    function deposit(uint256 _amount, uint256 _minLpReceived) external returns (uint256) {}

    function deposit(
        uint256 _amount,
        uint256 _minLpReceived,
        bool stake
    ) external returns (uint256) {}

    function exchangeRate() external view returns (uint256) {}

    function depegThreshold() external view override returns (uint256) {}

    function maxIdleCurveLpRatio() external view returns (uint256) {}

    function getPoolWeight(address curvePool) external view returns (uint256) {}

    function setMaxIdleCurveLpRatio(uint256 value) external {}

    function updateDepegThreshold(uint256 value) external {}

    function computeDeviationRatio() external view returns (uint256) {}

    function allPools() external view returns (address[] memory) {}

    function poolsCount() external view override returns (uint256) {}

    function getPoolAtIndex(uint256 _index) external view returns (address) {}

    function curveLpOracle() external view returns (IOracle) {}

    function tokenOracle() external view returns (IOracle) {}

    function claimPoolEarnings() external {}

    function handleInvalidConvexPid(address pool) external {}

    function handleDepeggedCurvePool(address curvePool_) external {}

    function unstakeAndWithdraw(uint256 _amount, uint256 _minAmount) external returns (uint256) {}

    function unstakeAndWithdraw(
        uint256 _amount,
        uint256 _minAmount,
        address to
    ) external returns (uint256) {}

    function withdraw(uint256 _amount, uint256 _minAmount) external returns (uint256) {}

    function withdraw(uint256 _amount, uint256 _minAmount, address to) external returns (uint256) {}

    function isBalanced() external view returns (bool) {}

    function updateWeights(PoolWeight[] memory poolWeights) external {
        for (uint256 i = 0; i < poolWeights.length; i++) {
            weights.set(poolWeights[i].poolAddress, poolWeights[i].weight);
        }
    }

    function shutdownPool() external override {
        isShutdown = true;
    }

    function getWeight(address curvePool) external view returns (uint256) {
        return weights.get(curvePool);
    }

    function getWeights() external view override returns (PoolWeight[] memory) {
        uint256 length_ = weights.length();
        PoolWeight[] memory weights_ = new PoolWeight[](length_);
        for (uint256 i; i < length_; i++) {
            (address pool_, uint256 weight_) = weights.at(i);
            weights_[i] = PoolWeight(pool_, weight_);
        }
        return weights_;
    }

    function totalCurveLpBalance(address curvePool_) public view returns (uint256) {}

    function getAllocatedUnderlying() external pure override returns (PoolWithAmount[] memory) {
        PoolWithAmount[] memory value_;
        return value_;
    }

    function rebalance() external {}

    function updateTotalUnderlying(uint256 amount) public {
        _useFakeTotalUnderlying = true;
        _fakeTotalUnderlying = amount;
    }

    function cachedTotalUnderlying() external view returns (uint256) {
        return _fakeTotalUnderlying;
    }

    function rebalancingRewardActive() external view returns (bool) {}

    function totalUnderlying() public view returns (uint256) {
        return _fakeTotalUnderlying;
    }

    function getTotalAndPerPoolUnderlying()
        external
        view
        returns (
            uint256 totalUnderlying_,
            uint256 totalAllocated_,
            uint256[] memory perPoolUnderlying_
        )
    {}

    function mintLPTokens(address _account, uint256 _amount) external {
        mintLPTokens(_account, _amount, false);
    }

    function mintLPTokens(address _account, uint256 _amount, bool stake) public {
        if (!stake) {
            lpToken.mint(_account, _amount, _account);
            updateTotalUnderlying(totalUnderlying() + _amount);
        } else {
            lpToken.mint(address(this), _amount, _account);
            IERC20(lpToken).approve(address(controller.lpTokenStaker()), _amount);
            controller.lpTokenStaker().stakeFor(_amount, address(this), _account);
            updateTotalUnderlying(totalUnderlying() + _amount);
        }
    }

    function burnLPTokens(address _account, uint256 _amount) external {
        controller.lpTokenStaker().unstake(_amount, address(this));
        lpToken.burn(address(this), _amount, _account);
        updateTotalUnderlying(totalUnderlying() - _amount);
    }

    function computeTotalDeviation() external pure returns (uint256) {
        return 0;
    }

    function totalDeviationAfterWeightUpdate() external pure returns (uint256) {
        return 0;
    }

    function removePool(address pool) external {}

    function addPool(address pool) external {}

    function usdExchangeRate() external pure override returns (uint256) {
        return 1e18;
    }
}
