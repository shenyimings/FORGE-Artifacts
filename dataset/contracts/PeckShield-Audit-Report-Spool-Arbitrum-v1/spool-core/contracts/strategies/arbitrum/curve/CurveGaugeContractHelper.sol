// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;


import "../../../interfaces/ISingleRewardStrategyContractHelper.sol";

import "../../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../../external/interfaces/curve/ILiquidityGauge.sol";
import "../../../external/interfaces/curve/IGaugeFactory.sol";

/**
 * @notice Curve Liquidity Gauge contract helper
 */
contract CurveGaugeContractHelper is ISingleRewardStrategyContractHelper {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice Liquidity gauge
    ILiquidityGauge public immutable liquidityGauge;
    /// @notice Minter contract
    IGaugeFactory public immutable factory;
    /// @notice Spool contract
    address public immutable spool;
    /// @notice LP Token contract
    IERC20 public immutable lpToken;
    /// @notice Reward Token contract
    IERC20 public immutable rewardToken;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _spool Spool contract
     * @param _liquidityGauge LiquidityGauge contract
     * @param _rewardToken Reward token
     */
    constructor(
        address _spool,
        ILiquidityGauge _liquidityGauge,
        IERC20 _rewardToken
    ) {
        require(_spool != address(0), "CurveGaugeContractHelper::constructor: Spool address cannot be 0");
        require(address(_liquidityGauge) != address(0), "CurveGaugeContractHelper::constructor: LiquidityGauge address cannot be 0");
        
        spool = _spool;

        factory = IGaugeFactory(_liquidityGauge.factory());
        lpToken = IERC20(_liquidityGauge.lp_token());
        liquidityGauge = _liquidityGauge;
        rewardToken = _rewardToken;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Claim reward
     * @param executeClaim true to swap rewards to underlying
     * @return rewardTokenAmount claimed token amount
     * @return didClaimNewRewards flag if new rewards were claimed
     */
    function claimReward(
        bool executeClaim
    )
        external
        override
        onlySpool
    returns(
        uint256 rewardTokenAmount,
        bool didClaimNewRewards
    )
    {
        if (executeClaim) {
            factory.mint(address(liquidityGauge));
        }

        rewardTokenAmount = rewardToken.balanceOf(address(this));
        if (rewardTokenAmount > 0) {
            rewardToken.safeTransfer(msg.sender, rewardTokenAmount);
            didClaimNewRewards = true;
        }
    }

    /**
     * @notice Deposit
     * Requirements:
     *  - Caller must be main spool contract
     * @param lp Amount of lp tokens to deposit
     */
    function deposit(uint256 lp) external override onlySpool {
        lpToken.safeApprove(address(liquidityGauge), lp);
        liquidityGauge.deposit(lp);

        if (lpToken.allowance(address(this), address(liquidityGauge)) > 0) {
            lpToken.safeApprove(address(liquidityGauge), 0);
        }
    }

    /**
     * @notice Withdraw
     * Requirements:
     *  - Caller must be main spool contract
     * @param lp Amount of LP tokens to withdraw
     */
    function withdraw(uint256 lp) external override onlySpool {
        liquidityGauge.withdraw(lp);
        lpToken.safeTransfer(msg.sender, lp);
    }

    /**
     * @notice Withdraw all
     * Requirements:
     *  - Caller must be main spool contract
     */
    function withdrawAll() external override onlySpool {
        liquidityGauge.withdraw(liquidityGauge.balanceOf(address(this)));
        lpToken.safeTransfer(msg.sender, lpToken.balanceOf(address(this)));
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Throws if caller is not main spool contract
     */
    function _onlySpool() private view {
        require(msg.sender == spool, "CurveGaugeContractHelper::_onlySpool: Caller is not the Spool contract");
    }

    /* ========== MODIFIERS ========== */

    /**
     * @notice Throws if caller is not main spool contract
     */
    modifier onlySpool() {
        _onlySpool();
        _;
    }
}
