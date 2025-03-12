// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./CurveStrategyBaseV2.sol";
import "../../../external/interfaces/curve/IStableSwap4Pool.sol";
import "../../../external/interfaces/curve/ICurvePoolV2.sol";

/**
 * @notice Curve 4Coins base strategy
 */
abstract contract CurveStrategy4CoinsBase is CurveStrategyBaseV2 {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    /// @notice Total number of coins
    uint256 internal constant TOTAL_COINS = 4;

    /// @notice index of underlying coin in pool
    int128 public immutable nCoin;

    /* ========== STATE VARIABLES ========== */

    /// @notice Stable swap pool
    IStableSwap4Pool public immutable pool4Coins;

    /* ========== CONSTRUCTOR ========== */

    constructor() {
        pool4Coins = IStableSwap4Pool(pool);
        nCoin = _getNCoin();
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

        pool4Coins.add_liquidity(amounts, slippage);
    }

    /**
     * @notice Withdraw
     * @param amount Amount
     * @param slippage Slippage
     */
    function _curveWithdrawal(uint256 amount, uint256 slippage) internal override {
        pool4Coins.remove_liquidity_one_coin(amount, nCoin, slippage);
    }

    /**
     * @notice Calculate Withdraw using pool calculation function
     */
    function _curveCalcWithdrawal() internal override view returns(uint256) {
        return pool4Coins.calc_withdraw_one_coin(ONE_LP_UNIT, nCoin);
    }

    /**
     * @notice get underlying coin index from the pool
     */
    function _getNCoin() internal view returns(int128 coin) {
        ICurvePoolV2 poolV2 = ICurvePoolV2(pool);
        while (poolV2.coins(coin) != address(underlying)) coin++;
    }
}
