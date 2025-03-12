// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../curve/base/CurveStrategyMetapoolV2Base.sol";

import "../../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../../external/interfaces/yearn/IYearnTokenVault.sol";

/**
 * @notice Yearn Metapool Strategy implementation
 */
contract YearnMetapoolStrategy is CurveStrategyMetapoolV2Base {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice Vault contract
    IYearnTokenVault public immutable vault;

    /// @notice One yearn vault share amount
    uint256 public immutable oneShare;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _vault Vault contract
     * @param _underlying Underlying asset
     */
    constructor(
        IYearnTokenVault _vault,
        ICurvePool _basePool,
        address _depositZap,
        IERC20 _lpToken,
        IERC20 _underlying,
        address _self
    )
        BaseStrategy(_underlying, 0, 2, 2, 2, false, true, _self)
        CurveStrategyBaseV3(_depositZap, _lpToken)
        CurveStrategyMetapoolV2Base(_basePool)
    {
        require(address(_vault) != address(0), "YearnMetapoolStrategy::constructor: Vault address cannot be 0");
        vault = _vault;
        oneShare = 10**uint256(_vault.decimals());
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */
    /**
     * @notice Returns total strategy balance including pending rewards
     * @return strategyBalance total strategy balance including pending rewards
     */
    function _getStrategyUnderlyingWithRewards() internal view override virtual returns(uint128) {
        return getStrategyBalance();
    }

    /**
     * @notice Process rewards - not supported
     */
    function _processRewards(SwapData[] calldata) internal pure override {
        revert("NoRewardStrategy::_processRewards: Strategy does not have rewards");
    }

    /**
     * @notice Process fast withdraw
     * @param shares Amount of shares
     * @param slippages Slippages array
     * @return withdrawnAmount Underlying withdrawn amount
     */
    function _processFastWithdraw(uint128 shares, uint256[] memory slippages, SwapData[] calldata) internal virtual override returns(uint128) {
        return _withdraw(shares, slippages);
    }

    /**
     * @notice Deposit
     * @param lp Amount of lp to deposit
     * @param slippages Min amount (encoded)
     */
    function _handleDeposit(uint256 lp, uint256 slippages) internal override returns(uint) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages);
        require(isDeposit, "YearnMetapoolStrategy::_handleDeposit: Withdraw slippage provided");

        // deposit lpToken
        lpToken.safeApprove(address(vault), lp);

        uint256 yearnTokenBefore = vault.balanceOf(address(this));
        vault.deposit(lp, address(this));
        uint256 yearnTokenNew = vault.balanceOf(address(this)) - yearnTokenBefore;
        _resetAllowance(lpToken, address(vault));

        require(
            yearnTokenNew >= slippage,
            "YearnMetapoolStrategy::_deposit: Insufficient Yearn Amount Minted"
        );

        emit Slippage(self, lpToken, true, lp, yearnTokenNew);

        return yearnTokenNew;
    }

    /**
     * @notice Withdraw
     * @param lp amount of lp to withdraw
     * @param slippages Min amount (encoded)
     */
    function _handleWithdrawal(uint256 lp, uint256 slippages) internal override returns(uint) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages);
        require(!isDeposit, "YearnMetapoolStrategy::_handleWithdraw: Deposit slippage provided");

        // withdraw lp tokens from vault
        uint256 lpBefore = lpToken.balanceOf(address(this));
        vault.withdraw(lp, address(this), slippage);
        uint256 lpWithdrawn = lpToken.balanceOf(address(this)) - lpBefore;
        
        emit Slippage(self, lpToken, false, lp, lpWithdrawn);
        return lpWithdrawn;
    }

    /**
     * @notice Emergency withdraw
     * @param data Data to perform emergency withdrawal
     */
    function _handleEmergencyWithdrawal(address, uint256[] calldata data) internal override {
        // if no data provided set max loss to 100%
        uint256 maxLoss = data.length > 0 ? data[0] : 100_00;
        strategies[self].lpTokens = 0;

        vault.withdraw(
            type(uint256).max,
            address(this),
            maxLoss
        );
    }
    
    /**
     * @notice Handle any extra logic for calculating underlying from LP
     */
    function _preLpToCoin(uint256 _lp) internal view override returns(uint){
        return _getYearnTokenValue(_lp);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Get value of the desired yvCurve-MIM2CRV amount in token (MIM2CRV)
     * @param yearnTokenAmount yvCurve-MIM2CRV value
     * @return amount value of `yearnTokenAmount` in token (MIM2CRV)
     */
    function _getYearnTokenValue(uint256 yearnTokenAmount) private view returns(uint256) {
        if (yearnTokenAmount == 0)
            return 0;
        return (yearnTokenAmount * vault.pricePerShare()) / oneShare;
    }
}
