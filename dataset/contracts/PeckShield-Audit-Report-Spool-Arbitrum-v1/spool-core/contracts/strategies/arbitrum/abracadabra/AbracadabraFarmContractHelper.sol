// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../../../interfaces/ISingleRewardStrategyContractHelper.sol";

import "../../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../../external/interfaces/abracadabra/ISorbettiere.sol";

/**
 * @notice Abracadabra farm contract helper
 */
contract AbracadabraFarmContractHelper is ISingleRewardStrategyContractHelper {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice Spool contract
    address public immutable spool;
    /// @notice Sorbettiere(Farm) contract
    ISorbettiere public immutable farm;
    /// @notice LP Token contract
    IERC20 public immutable lpToken;
    /// @notice Reward Token contract (SPELL)
    IERC20 public immutable rewardToken;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _spool Spool contract
     * @param _farm Farm contract
     */
    constructor(
        address _spool,
        ISorbettiere _farm
    ) {
        require(_spool != address(0), "AbracadabraFarmContractHelper::constructor: Spool address cannot be 0");
        require(address(_farm) != address(0), "AbracadabraFarmContractHelper::constructor: Farm address cannot be 0");
        
        spool = _spool;
        farm = _farm;

        (address stakingToken,,,,) = _farm.poolInfo(0);
        lpToken = IERC20(stakingToken);
        rewardToken = IERC20(_farm.ice());
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
            farm.withdraw(0, 0);
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
        lpToken.safeApprove(address(farm), lp);
        farm.deposit(0, lp);

        if (lpToken.allowance(address(this), address(farm)) > 0) {
            lpToken.safeApprove(address(farm), 0);
        }
    }

    /**
     * @notice Withdraw
     * Requirements:
     *  - Caller must be main spool contract
     * @param lp Amount of LP tokens to withdraw
     */
    function withdraw(uint256 lp) external override onlySpool {
        farm.withdraw(0, lp);
        lpToken.safeTransfer(msg.sender, lp);
    }

    /**
     * @notice Withdraw all
     * Requirements:
     *  - Caller must be main spool contract
     */
    function withdrawAll() external override onlySpool {
        farm.emergencyWithdraw(0);
        lpToken.safeTransfer(msg.sender, lpToken.balanceOf(address(this)));
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Throws if caller is not main spool contract
     */
    function _onlySpool() private view {
        require(msg.sender == spool, "AbracadabraFarmContractHelper::_onlySpool: Caller is not the Spool contract");
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
