// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../ProcessStrategy.sol";
import "../../../external/interfaces/curve/ICurvePool.sol";

abstract contract CurveStrategyBaseV2 is ProcessStrategy {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */
    
    /// @notice normalizes LP calculation
    uint256 internal constant ONE_LP_UNIT = 1e18;

    /* ========== STATE VARIABLES ========== */

    /// @notice Pool used for managing liquidity
    address public immutable pool;
    /// @notice LP token for the pool
    IERC20 public immutable lpToken;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _pool,
        IERC20 _lpToken
    ) {
        require(_pool != address(0), "CurveStrategyBaseV2::constructor: Curve Pool address cannot be 0");
        require(address(_lpToken) != address(0), "CurveStrategyBaseV2::constructor: Token address cannot be 0");

        pool = _pool;
        lpToken = _lpToken;
    }

    /* ========== VIEWS ========== */
    
    /// @notice get shares balance of the strategy in underlying
    function getStrategyBalance() public view override returns(uint128) {
        return _lpToCoin(_lpBalance());
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @notice deposit underlying into the pool, and deposit the received LP token into the liquiidity gauge
     * @param amount amount of underlying to deposit
     * @param slippages minimum amount(s) to be received
     */
    function _deposit(uint128 amount, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(isDeposit, "CurveStrategyBaseV2::_deposit: Withdraw slippage provided");
        
        // deposit underlying
        underlying.safeApprove(pool, amount);
        
        uint256 lpBefore = lpToken.balanceOf(address(this));
        _curveDeposit(amount, slippage);
        uint256 newLp = lpToken.balanceOf(address(this)) - lpBefore;
        _resetAllowance(underlying, pool);

        emit Slippage(self, underlying, true, amount, newLp);

        strategies[self].lpTokens += newLp;

        _handleDeposit(newLp);
        return _lpToCoin(newLp);
    }

    /**
     * @notice withdraw LP from the liquidity gauge, and withdraw the underlying tokens from the pool
     * @param shares amount of shares to withdraw
     * @param slippages minimum amount(s) to be received
     */
    function _withdraw(uint128 shares, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(!isDeposit, "CurveStrategyBaseV2::_withdraw: Deposit slippage provided");

        uint256 totalLp = _lpBalance();

        uint256 withdrawLp = (totalLp * shares) / strategies[self].totalShares;
        strategies[self].lpTokens -= withdrawLp;

        // withdraw staked lp tokens
        _handleWithdrawal(withdrawLp);

        // withdraw fTokens from vault
        uint256 undelyingBefore = underlying.balanceOf(address(this));
        lpToken.safeApprove(pool, withdrawLp);

        _curveWithdrawal(withdrawLp, slippage);

        _resetAllowance(lpToken, pool);

        uint256 underlyingWithdrawn = underlying.balanceOf(address(this)) - undelyingBefore;

        emit Slippage(self, underlying, false, shares, underlyingWithdrawn);

        return SafeCast.toUint128(underlyingWithdrawn);
    }

    /**
     * @notice Emergency withdraw from curve pool
     * @param recipient receiver of the withdrawn amount
     * @param data any extra data necessary to perform withdraw
     */
    function _emergencyWithdraw(address recipient, uint256[] calldata data) internal override {
        uint256 slippage = data.length > 0 ? data[0] : 0;

        uint256[] calldata poolData = data.length > 0 ? data[1:] : data;

        uint256 lpBefore = lpToken.balanceOf(address(this));
        _handleEmergencyWithdrawal(recipient, poolData);
        uint256 newLp = lpToken.balanceOf(address(this)) - lpBefore;

        lpToken.safeApprove(pool, newLp);
        _curveWithdrawal(newLp, slippage);
        _resetAllowance(lpToken, pool);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @notice get lp tokens for the strategy
    function _lpBalance() internal view returns (uint256) {
        return strategies[self].lpTokens;
    }

    /**
     * @notice convert LP to underlying
     * @param lp amount of lp tokens to convert
     */
    function _lpToCoin(uint256 lp) internal view returns (uint128) {
        if (lp == 0)
            return 0;
        
        uint256 lpToCoin = _curveCalcWithdrawal();

        uint256 result = (lp * lpToCoin) / ONE_LP_UNIT;

        return SafeCast.toUint128(result);
    }

    /* ========== VIRTUAL FUNCTIONS ========== */
    
    function _curveDeposit(uint256 amount, uint256 slippage) internal virtual;

    function _curveWithdrawal(uint256 amount, uint256 slippage) internal virtual;

    function _curveCalcWithdrawal() internal virtual view returns(uint256);

    function _handleDeposit(uint256 lp) internal virtual;

    function _handleWithdrawal(uint256 lp) internal virtual;

    function _handleEmergencyWithdrawal(address recipient, uint256[] calldata data) internal virtual;
}
