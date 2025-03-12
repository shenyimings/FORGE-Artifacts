// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./CurveStrategyBaseV2.sol";
import "../../../external/interfaces/curve/IDepositZap.sol";

/**
 * @notice Curve Metapool base strategy
 */
abstract contract CurveStrategyMetapoolBase is CurveStrategyBaseV2 {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    /// @notice Base number of coins for every pool
    uint256 internal constant TOTAL_COINS = 4;

    /// @notice index of underlying coin in pool
    int128 public immutable nCoin;
    
    /// @notice deposit zap contract, wrapper around pool
    IDepositZap public immutable depositZap;

    /* ========== CONSTRUCTOR ========== */

    constructor(ICurvePool _basePool) {
        depositZap = IDepositZap(pool);

        nCoin = _getNCoin(_basePool);
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @notice Deposit
     * @param amount Amount
     * @param slippage Slippage
     */
    function _curveDeposit(uint256 amount, uint256 slippage) internal override {
        uint256[TOTAL_COINS] memory amounts;
        amounts[uint128(nCoin)] = amount;
        
        depositZap.add_liquidity(address(lpToken), amounts, slippage);
    }

    /**
     * @notice Withdraw
     * @param amount Amount
     * @param slippage Slippage
     */
    function _curveWithdrawal(uint256 amount, uint256 slippage) internal override {
        depositZap.remove_liquidity_one_coin(address(lpToken), amount, nCoin, slippage);
    }

    /**
     * @notice Calc Withdraw
     */
    function _curveCalcWithdrawal() internal override view returns(uint256) {
        return depositZap.calc_withdraw_one_coin(address(lpToken), ONE_LP_UNIT, nCoin);
    }

    /**
     * @notice get underlying coin index from the pool
     * @param basePool pool used to get the underlying coin index
     */
    function _getNCoin(ICurvePool basePool) internal view returns(int128) {
        uint128 _coin;
        while (basePool.coins(_coin) != address(underlying)) _coin++;
        _coin += 1; // index is incremented by 1 in deposit zap vs. base pool
        return int128(_coin);
    }
}
