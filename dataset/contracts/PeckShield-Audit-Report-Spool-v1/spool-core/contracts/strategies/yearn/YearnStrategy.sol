// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../NoRewardStrategy.sol";
import "../../external/interfaces/yearn/IYearnTokenVault.sol";

contract YearnStrategy is NoRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IYearnTokenVault public immutable vault;
    uint256 public immutable oneShare;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IYearnTokenVault _vault,
        IERC20 _underlying
    )
        NoRewardStrategy(_underlying, 1, 1, 1)
    {
        require(address(_vault) != address(0), "YearnStrategy::constructor: Vault address cannot be 0");
        vault = _vault;
        oneShare = 10**uint256(_vault.decimals());
    }

    /* ========== VIEWS ========== */

    function getStrategyBalance() public view override returns(uint128) {
        uint256 yearnTokenAmount = vault.balanceOf(address(this));
        return SafeCast.toUint128(_getYearnTokenValue(yearnTokenAmount));
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _deposit(uint128 amount, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(isDeposit, "YearnStrategy::_deposit: Withdraw slippage provided");

        // deposit underlying
        underlying.safeApprove(address(vault), amount);

        uint256 yearnTokenBefore = vault.balanceOf(address(this));
        vault.deposit(amount, address(this));
        uint256 yearnTokenNew = vault.balanceOf(address(this)) - yearnTokenBefore;

        require(
            yearnTokenNew >= slippage,
            "YearnStrategy::_deposit: Insufficient Yearn Amount Minted"
        );

        return SafeCast.toUint128(_getYearnTokenValue(yearnTokenNew));
    }

    function _withdraw(uint128 shares, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(!isDeposit, "YearnStrategy::_withdraw: Deposit slippage provided");

        uint256 yearnTokenBalance = vault.balanceOf(address(this));
        uint256 yearnTokenWithdraw = (yearnTokenBalance * shares) / strategies[self].totalShares;

        // withdraw idle tokens from vault
        uint256 undelyingBefore = underlying.balanceOf(address(this));
        vault.withdraw(yearnTokenWithdraw, address(this), slippage);
        uint256 undelyingWithdrawn = underlying.balanceOf(address(this)) - undelyingBefore;

        return SafeCast.toUint128(undelyingWithdrawn);
    }

    function _emergencyWithdraw(address recipient, uint256[] calldata data) internal override {
        // if no data provided set max loss to 100%
        uint256 maxLoss = data.length > 0 ? data[0] : 100_00;

        vault.withdraw(
            type(uint256).max,
            recipient,
            maxLoss
        );
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _getYearnTokenValue(uint256 yearnTokenAmount) private view returns(uint256) {
        if (yearnTokenAmount == 0)
            return 0;
        return (yearnTokenAmount * vault.pricePerShare()) / oneShare;
    }
}