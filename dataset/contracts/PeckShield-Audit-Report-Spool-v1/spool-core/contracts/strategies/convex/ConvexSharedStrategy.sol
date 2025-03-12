// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../curve/base/CurveStrategy3CoinsBase.sol";
import "../MultipleRewardStrategy.sol";

import "../../external/interfaces/convex/IBooster.sol";
import "../../external/interfaces/convex/IBaseRewardPool.sol";
import "../../interfaces/IStrategyContractHelper.sol";

contract ConvexSharedStrategy is CurveStrategy3CoinsBase, MultipleRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */
    
    /// @notice There are 2 base reward tokens: CRV and CVX
    uint256 internal constant BASE_REWARDS_COUNT = 2;

    /* ========== STATE VARIABLES ========== */

    IBooster public immutable booster;
    uint256 public immutable pid;
    IBaseRewardPool public immutable crvRewards;
    IERC20 public immutable rewardToken;
    IERC20 public immutable cvxToken;
    IStrategyContractHelper public immutable boosterHelper;
    bytes32 private immutable _sharedKey;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IBooster _booster,
        uint256 _boosterPoolId,
        IStableSwap3Pool _pool,
        IERC20 _lpToken,
        IERC20 _underlying,
        IStrategyContractHelper _boosterDeposit
    )
        BaseStrategy(_underlying, 0, 1, 1, 1, false)
        CurveStrategyBase(_pool, _lpToken)
    {
        require(address(_booster) != address(0), "ConvexSharedStrategy::constructor: Booster address cannot be 0");
        booster = _booster;
        pid = _boosterPoolId;

        IBooster.PoolInfo memory cvxPool = _booster.poolInfo(_boosterPoolId);

        require(cvxPool.lptoken == address(_lpToken), "ConvexSharedStrategy::constructor: Booster and curve lp tokens not the same");
        
        crvRewards = IBaseRewardPool(cvxPool.crvRewards);
        rewardToken = crvRewards.rewardToken();
        cvxToken = IERC20(_booster.minter());

        boosterHelper = _boosterDeposit;
        
        _sharedKey = _calculateSharedKey();
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function initialize() external override {
        _initialize();
    }

    function disable() external override {
        _disable();
    }

    /**
     * @dev Dynamically return slippage length
     */
    function _getRewardSlippageSlots() internal view override returns(uint256) {
        return crvRewards.extraRewardsLength() + BASE_REWARDS_COUNT;
    }

    /**
     * @dev Transfers lp tokens to helper contract, to deposit them into booster
     */
    function _handleDeposit(uint256 lp) internal override {
        lpToken.safeTransfer(address(boosterHelper), lp);

        boosterHelper.deposit(lp);
    }

    /**
     * @dev Withdraw lp tokens from helper contract
     */
    function _handleWithdrawal(uint256 lp) internal override {

        boosterHelper.withdraw(lp);
    }

    function _handleEmergencyWithdrawal(address, uint256[] calldata data) internal override {
        // NOTE: withdrawAll removes all lp tokens from the liquidity gauge,
        //       including the tokens from the other strategies in the same pool
        uint256 value = data.length > 0 ? data[0] : 0;

        if (value == 0) {
            boosterHelper.withdraw(_lpBalance());
            strategies[self].lpTokens = 0;
        } else {
            (bool withdrawAll, uint256 lpTokens) = _getSlippageAction(value);
            
            if (withdrawAll) {
                boosterHelper.withdrawAll();
                strategies[self].lpTokens = 0;
            } else {
                boosterHelper.withdraw(lpTokens);

                if (lpTokens >= strategies[self].lpTokens) {
                    strategies[self].lpTokens = 0;
                } else {
                    strategies[self].lpTokens -= lpTokens;
                }
            }
        }
    }

    function _claimMultipleRewards(uint128 shares, SwapData[] calldata swapData) internal override returns(Reward[] memory rewards) {
        if (swapData.length > 0) {
            uint256 extraRewardCount = crvRewards.extraRewardsLength();
            
            rewards = new Reward[](extraRewardCount + BASE_REWARDS_COUNT);

            address[] memory rewardTokens = _getRewardAddresses(extraRewardCount);
            _claimStrategyRewards(rewardTokens);

            Strategy storage strategy = strategies[self];
            for (uint256 i = 0; i < rewardTokens.length; i++) {

                if (swapData[i].slippage > 0) {
                    uint256 rewardTokenAmount = strategy.pendingRewards[rewardTokens[i]];

                    if (rewardTokenAmount > 0) {
                        uint256 claimedAmount = _getRewardClaimAmount(shares, rewardTokenAmount);

                        if (rewardTokenAmount > claimedAmount) {
                            // if we don't swap all the tokens (fast withdraw), store the amount left 
                            uint256 rewardAmountLeft = rewardTokenAmount - claimedAmount;
                            strategy.pendingRewards[rewardTokens[i]] = rewardAmountLeft;
                        } else {
                            strategy.pendingRewards[rewardTokens[i]] = 0;
                        }

                        rewards[i] = Reward(claimedAmount, IERC20(rewardTokens[i]));
                    }
                }
            }
        }
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _claimStrategyRewards(address[] memory rewardTokens) private {
        // check if any other shared strategy has claimed in the same block
        if (strategiesShared[_sharedKey].lastClaimBlock < block.number) {
            
            (
                uint256[] memory rewardTokenAmounts,
                bool didClaimNewRewards
            ) = boosterHelper.claimRewards(rewardTokens, true);

            if (didClaimNewRewards) {
                _spreadRewardsToSharedStrats(rewardTokens, rewardTokenAmounts);
            }
            
            strategiesShared[_sharedKey].lastClaimBlock = uint32(block.number);
        }
    }

    function _getRewardAddresses(uint256 extraRewardCount) private view returns(address[] memory) {
        address[] memory rewardAddresses = new address[](extraRewardCount + BASE_REWARDS_COUNT);
        rewardAddresses[0] = address(rewardToken);
        rewardAddresses[1] = address(cvxToken);

        for (uint256 i = 0; i < extraRewardCount; i++) {
            rewardAddresses[i + BASE_REWARDS_COUNT] = address(crvRewards.extraReward(i));
        }

        return rewardAddresses;
    }

    function _spreadRewardsToSharedStrats(address[] memory rewardTokens, uint256[] memory rewardTokenAmounts) private {
        StrategiesShared storage stratsShared = strategiesShared[_sharedKey];

        uint256 sharedStratsCount = stratsShared.stratsCount;
        address[] memory stratAddresses = new address[](sharedStratsCount);
        uint256[] memory stratLpTokens = new uint256[](sharedStratsCount);

        uint256 totalLpTokens;
        for(uint256 i = 0; i < sharedStratsCount; i++) {
            stratAddresses[i] = stratsShared.stratAddresses[i];
            stratLpTokens[i] = strategies[stratAddresses[i]].lpTokens;
            totalLpTokens += stratLpTokens[i];
        }

        for(uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokenAmounts[i] > 0) {
                for(uint256 j = 0; j < sharedStratsCount; j++) {
                    strategies[stratAddresses[j]].pendingRewards[rewardTokens[i]] += 
                        (rewardTokenAmounts[i] * stratLpTokens[j]) / totalLpTokens;
                }
            }
        }
    }

    function _calculateSharedKey() private view returns(bytes32) {
        return keccak256(abi.encodePacked(address(booster), pid));
    }

    function _getSharedKey() internal view override returns(bytes32) {
        return _sharedKey;
    }
}