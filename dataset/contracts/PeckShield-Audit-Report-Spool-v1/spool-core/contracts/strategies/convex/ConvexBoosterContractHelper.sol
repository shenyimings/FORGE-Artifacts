// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/IStrategyContractHelper.sol";

import "../../external/interfaces/convex/IBooster.sol";
import "../../external/interfaces/convex/IBaseRewardPool.sol";

contract ConvexBoosterContractHelper is IStrategyContractHelper {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    address public immutable spool;
    IBooster public immutable booster;
    uint256 public immutable pid;
    IBaseRewardPool public immutable crvRewards;
    IERC20 public immutable lpToken;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _spool,
        IBooster _booster,
        uint256 _boosterPoolId
    ) {
        require(_spool != address(0), "ConvexBoosterContractHelper::constructor: Spool address cannot be 0");
        require(address(_booster) != address(0), "ConvexBoosterContractHelper::constructor: Booster address cannot be 0");
        
        spool = _spool;
        booster = _booster;
        pid = _boosterPoolId;

        IBooster.PoolInfo memory cvxPool = _booster.poolInfo(_boosterPoolId);        
        crvRewards = IBaseRewardPool(cvxPool.crvRewards);
        lpToken = IERC20(cvxPool.lptoken);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function claimRewards(
        address[] memory rewardTokens,
        bool executeClaim
    )
        external
        override
        onlySpool
    returns(
        uint256[] memory rewardTokenAmounts,
        bool didClaimNewRewards
    )
    {
        if (executeClaim) {
            crvRewards.getReward();
        }

        rewardTokenAmounts = new uint256[](rewardTokens.length);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokenAmounts[i] = IERC20(rewardTokens[i]).balanceOf(address(this));

            if (rewardTokenAmounts[i] > 0) {
                IERC20(rewardTokens[i]).safeTransfer(msg.sender, rewardTokenAmounts[i]);
                didClaimNewRewards = true;
            }
        }
    }

    function deposit(uint256 lp) external override onlySpool {
        lpToken.safeApprove(address(booster), lp);

        booster.deposit(pid, lp, true);
    }

    function withdraw(uint256 lp) external override onlySpool {
        crvRewards.withdrawAndUnwrap(lp, false);
        lpToken.safeTransfer(msg.sender, lp);
    }

    function withdrawAll() external override onlySpool {
        crvRewards.withdrawAllAndUnwrap(false);
        lpToken.safeTransfer(msg.sender, lpToken.balanceOf(address(this)));
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _onlySpool() private view {
        require(msg.sender == spool, "ConvexBoosterContractHelper::_onlySpool: Caller is not the Spool contract");
    }

    /* ========== MODIFIERS ========== */

    modifier onlySpool() {
        _onlySpool();
        _;
    }
}