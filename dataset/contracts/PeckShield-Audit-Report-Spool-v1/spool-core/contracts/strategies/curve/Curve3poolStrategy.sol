// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../ClaimFullSingleRewardStrategy.sol";
import "./base/CurveStrategy3CoinsBase.sol";

import "../../external/interfaces/curve/ILiquidityGauge.sol";
import "../../external/interfaces/curve/IMinter.sol";


contract Curve3poolStrategy is ClaimFullSingleRewardStrategy, CurveStrategy3CoinsBase {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    ILiquidityGauge public immutable liquidityGauge;
    IMinter public immutable minter;
    bytes32 private immutable _sharedKey;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IStableSwap3Pool _pool,
        ILiquidityGauge _liquidityGauge,
        IERC20 _underlying
    )
        BaseStrategy(_underlying, 1, 1, 1, 1, false)
        CurveStrategyBase(_pool, IERC20(_liquidityGauge.lp_token()))
        ClaimFullSingleRewardStrategy(IERC20(_liquidityGauge.crv_token()))
    {
        liquidityGauge = _liquidityGauge;
        minter = IMinter(liquidityGauge.minter());

        _sharedKey = _calculateSharedKey();
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function initialize() external override {
        _initialize();
    }

    function disable() external override {
        _disable();
    }

    function _claimStrategyReward() internal override returns(uint128) {
        if (strategiesShared[_sharedKey].lastClaimBlock < block.number) {
            // claim
            uint256 rewardBefore = rewardToken.balanceOf(address(this));
            minter.mint(address(liquidityGauge));
            uint256 rewardAmount = rewardToken.balanceOf(address(this)) - rewardBefore;

            if (rewardAmount > 0) {
                _spreadRewardsToSharedStrats(rewardAmount);
            }

            strategiesShared[_sharedKey].lastClaimBlock = uint32(block.number);
        }

        return SafeCast.toUint128(strategies[self].pendingRewards[address(rewardToken)]);
    }

    function _handleDeposit(uint256 lp) internal override {
        lpToken.safeApprove(address(liquidityGauge), lp);

        liquidityGauge.deposit(lp);
    }

    function _handleWithdrawal(uint256 lp) internal override {
        liquidityGauge.withdraw(lp);
    }

    function _handleEmergencyWithdrawal(address, uint256[] calldata data) internal override {
        // NOTE: withdrawAll removes all lp tokens from the liquidity gauge,
        //       including the tokens from the other strategies in the same pool
        uint256 value = data.length > 0 ? data[0] : 0;

        uint256 withdrawLp;
        if (value == 0) {
            withdrawLp = _lpBalance();
        } else {
            (bool withdrawAll, uint256 lpTokens) = _getSlippageAction(value);
            
            if (withdrawAll) {
                withdrawLp = liquidityGauge.balanceOf(address(this));
            } else {
                withdrawLp = lpTokens;
            }
        }
        
        // set remove lp tokens, so we cannot withdraw many times 
        if (withdrawLp >= strategies[self].lpTokens) {
            strategies[self].lpTokens = 0;
        } else {
            strategies[self].lpTokens -= withdrawLp;
        }

        liquidityGauge.withdraw(withdrawLp);
    }

    function _getSharedKey() internal view override returns(bytes32) {
        return _sharedKey;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _spreadRewardsToSharedStrats(uint256 rewardAmount) private {        
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

        for(uint256 i = 0; i < sharedStratsCount; i++) {
            strategies[stratAddresses[i]].pendingRewards[address(rewardToken)] += 
                (rewardAmount * stratLpTokens[i]) / totalLpTokens;
        }
    }

    function _calculateSharedKey() private view returns(bytes32) {
        return keccak256(abi.encodePacked(address(pool), address(liquidityGauge)));
    }
}