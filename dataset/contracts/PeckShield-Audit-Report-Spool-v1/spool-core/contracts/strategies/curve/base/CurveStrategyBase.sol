// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../ProcessStrategy.sol";
import "../../../external/interfaces/curve/ICurvePool.sol";

abstract contract CurveStrategyBase is ProcessStrategy {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    uint256 internal constant ONE_LP_UNIT = 1e18;

    /* ========== STATE VARIABLES ========== */

    ICurvePool public immutable pool;
    IERC20 public immutable lpToken;
    int128 public immutable nCoin;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        ICurvePool _pool,
        IERC20 _lpToken
    ) {
        require(address(_pool) != address(0), "CurveStrategy::constructor: Curve Pool address cannot be 0");
        require(address(_lpToken) != address(0), "CurveStrategy::constructor: Token address cannot be 0");

        pool = _pool;
        lpToken = _lpToken;
        
        uint128 _nCoin = 0;
        while (_pool.coins(_nCoin) != address(underlying)) _nCoin++;
        nCoin = int128(_nCoin);
    }

    /* ========== VIEWS ========== */

    function getStrategyBalance() public view override returns(uint128) {
        return _lpToCoin(_lpBalance());
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _deposit(uint128 amount, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(isDeposit, "CurveStrategyBase::_deposit: Withdraw slippage provided");
        
        // deposit underlying
        underlying.safeApprove(address(pool), amount);
        
        uint256 lpBefore = lpToken.balanceOf(address(this));
        _curveDeposit(amount, slippage);
        uint256 newLp = lpToken.balanceOf(address(this)) - lpBefore;

        strategies[self].lpTokens += newLp;

        _handleDeposit(newLp);

        return _lpToCoin(newLp);
    }

    function _withdraw(uint128 shares, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(!isDeposit, "CurveStrategyBase::_withdraw: Deposit slippage provided");

        uint256 totalLp = _lpBalance();

        uint256 withdrawLp = (totalLp * shares) / strategies[self].totalShares;
        strategies[self].lpTokens -= withdrawLp;

        // withdraw staked lp tokens
        _handleWithdrawal(withdrawLp);

        // withdraw fTokens from vault
        uint256 undelyingBefore = underlying.balanceOf(address(this));
        pool.remove_liquidity_one_coin(withdrawLp, nCoin, slippage);
        uint256 undelyingWithdrawn = underlying.balanceOf(address(this)) - undelyingBefore;

        return SafeCast.toUint128(undelyingWithdrawn);
    }

    /**
     * @notice Emergency withdraw from curve pool
     */
    function _emergencyWithdraw(address recipient, uint256[] calldata data) internal override {
        uint256 slippage = data.length > 0 ? data[0] : 0;

        uint256[] calldata poolData = data.length > 0 ? data[1:] : data;

        uint256 lpBefore = lpToken.balanceOf(address(this));
        _handleEmergencyWithdrawal(recipient, poolData);
        uint256 newLp = lpToken.balanceOf(address(this)) - lpBefore;

        pool.remove_liquidity_one_coin(newLp, nCoin, slippage);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _lpBalance() internal view returns (uint256) {
        return strategies[self].lpTokens;
    }

    function _lpToCoin(uint256 lp) internal view returns (uint128) {
        if (lp == 0)
            return 0;
        
        uint256 lpToCoin = pool.calc_withdraw_one_coin(ONE_LP_UNIT, nCoin);

        uint256 result = (lp * lpToCoin) / ONE_LP_UNIT;

        return SafeCast.toUint128(result);
    }

    /* ========== VIRTUAL FUNCTIONS ========== */
    
    function _curveDeposit(uint256 amount, uint256 slippage) internal virtual;

    function _handleDeposit(uint256 lp) internal virtual;

    function _handleWithdrawal(uint256 lp) internal virtual;

    function _handleEmergencyWithdrawal(address recipient, uint256[] calldata data) internal virtual;
}