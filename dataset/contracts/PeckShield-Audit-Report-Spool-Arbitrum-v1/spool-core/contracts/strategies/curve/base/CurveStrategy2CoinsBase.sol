// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./CurveStrategyBaseV2.sol";
import "../../../external/interfaces/curve/IStableSwap2Pool.sol";
import "../../../external/interfaces/curve/ICurvePoolV3.sol";

/**
 * @notice Curve 2Coins base strategy
 */
abstract contract CurveStrategy2CoinsBase is CurveStrategyBaseV2 {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    /// @notice Total number of coins
    uint256 internal constant TOTAL_COINS = 2;

    /// @notice index of underlying coin in pool
    int128 public immutable nCoin;

    /* ========== STATE VARIABLES ========== */

    /// @notice Stable swap pool
    IStableSwap2Pool public immutable pool2Coins;

    /* ========== CONSTRUCTOR ========== */

    constructor() {
        pool2Coins = IStableSwap2Pool(pool);
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

        pool2Coins.add_liquidity(amounts, slippage);
    }

    /**
     * @notice Withdraw
     * @param amount Amount
     * @param slippage Slippage
     */
    function _curveWithdrawal(uint256 amount, uint256 slippage) internal override {
        pool2Coins.remove_liquidity_one_coin(amount, nCoin, slippage);
    }

    /**
     * @notice Calculate Withdraw using pool calculation function
     */
    function _curveCalcWithdrawal() internal override view returns(uint256) {
        return pool2Coins.calc_withdraw_one_coin(ONE_LP_UNIT, nCoin);
    }

    /**
     * @notice get underlying coin index from the pool
     */
    function _getNCoin() internal view returns(int128 coin) {
        ICurvePoolV3 curvePool = ICurvePoolV3(pool);
        while (curvePool.coins(uint256(int256(coin))) != address(underlying)) coin++;
    }
}