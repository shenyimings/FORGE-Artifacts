// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../ClaimFullSingleRewardStrategy.sol";

import "../../external/interfaces/harvest/Vault/IHarvestVault.sol";
import "../../external/interfaces/harvest/IHarvestPool.sol";

contract HarvestStrategy is ClaimFullSingleRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IHarvestVault public immutable vault;
    IHarvestPool public immutable pool;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IERC20 _farm,
        IHarvestVault _vault,
        IHarvestPool _pool,
        IERC20 _underlying
    )
        BaseStrategy(_underlying, 1, 0, 0, 0, false) 
        ClaimFullSingleRewardStrategy(_farm) 
    {
        require(address(_vault) != address(0), "HarvestStrategy::constructor: Vault address cannot be 0");
        require(address(_pool) != address(0), "HarvestStrategy::constructor: Pool address cannot be 0");
        vault = _vault;
        pool = _pool;
    }

    /* ========== VIEWS ========== */

    function getStrategyBalance() public view override returns(uint128) {
        uint256 fTokenBalance = pool.balanceOf(address(this));
        return SafeCast.toUint128(_getfTokenValue(fTokenBalance));
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _claimStrategyReward() internal override returns(uint128) {
        // claim
        uint256 rewardBefore = rewardToken.balanceOf(address(this));
        pool.getReward();
        uint256 rewardAmount = rewardToken.balanceOf(address(this)) - rewardBefore;

        // add already claimed rewards
        rewardAmount += strategies[self].pendingRewards[address(rewardToken)];

        return SafeCast.toUint128(rewardAmount);
    }

    function _deposit(uint128 amount, uint256[] memory) internal override returns(uint128) {

        // deposit underlying
        underlying.safeApprove(address(vault), amount);
        uint256 fTokenBefore = vault.balanceOf(address(this));
        vault.deposit(amount);
        uint256 fTokenNew = vault.balanceOf(address(this)) - fTokenBefore;

        // stake fTokens
        vault.approve(address(pool), fTokenNew);
        pool.stake(fTokenNew);

        return SafeCast.toUint128(_getfTokenValue(fTokenNew));
    }

    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {
        uint256 fTokensTotal = pool.balanceOf(address(this));

        uint256 fWithdrawAmount = (fTokensTotal * shares) / strategies[self].totalShares;

        // withdraw staked fTokens from pool
        pool.withdraw(fWithdrawAmount);

        // withdraw fTokens from vault
        uint256 undelyingBefore = underlying.balanceOf(address(this));
        vault.withdraw(fWithdrawAmount);
        uint256 undelyingWithdrawn = underlying.balanceOf(address(this)) - undelyingBefore;

        return SafeCast.toUint128(undelyingWithdrawn);
    }

    function _emergencyWithdraw(address, uint256[] calldata) internal override {
        pool.exit();
        vault.withdraw(vault.balanceOf(address(this)));
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _getfTokenValue(uint256 fTokenAmount) private view returns(uint256) {
        if (fTokenAmount == 0)
            return 0;

        uint256 vaultTotal = vault.underlyingBalanceWithInvestment();
        return (vaultTotal * fTokenAmount) / vault.totalSupply();
    }
}