// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./CurveStrategyBase.sol";
import "../../../external/interfaces/curve/IStableSwap3Pool.sol";

/**
 * @notice Curve 3Coins base strategy
 */
abstract contract CurveStrategy3CoinsBase is CurveStrategyBase {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    /// @notice Total number of coins
    uint256 internal constant TOTAL_COINS = 3;

    /* ========== STATE VARIABLES ========== */

    /// @notice Stable swap pool
    IStableSwap3Pool public immutable pool3Coins;

    /* ========== CONSTRUCTOR ========== */

    constructor() {
        pool3Coins = IStableSwap3Pool(address(pool));
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @dev register a strategy as shared strategy, using shared key
     */
    function _initialize() internal virtual {
        StrategiesShared storage stratsShared = strategiesShared[_getSharedKey()];
        
        stratsShared.stratAddresses[stratsShared.stratsCount] = self;
        stratsShared.stratsCount++;
    }

    /**
     * @notice Run after strategy was removed as a breakdown function
     */
    function _disable() internal virtual {
        StrategiesShared storage stratsShared = strategiesShared[_getSharedKey()];

        uint256 sharedStratsCount = stratsShared.stratsCount;

        for(uint256 i = 0; i < sharedStratsCount; i++) {
            if (stratsShared.stratAddresses[i] == self) {
                stratsShared.stratAddresses[i] = stratsShared.stratAddresses[sharedStratsCount - 1];
                delete stratsShared.stratAddresses[sharedStratsCount - 1];
                stratsShared.stratsCount--;
                break;
            }
        }
    }

    /**
     * @notice Deposit
     * @param amount Amount
     * @param slippage Slippage
     */
    function _curveDeposit(uint256 amount, uint256 slippage) internal override {
        uint256[TOTAL_COINS] memory amounts;
        amounts[uint128(nCoin)] = amount;

        pool3Coins.add_liquidity(amounts, slippage);
    }

    /* ========== VIRTUAL FUNCTIONS ========== */

    /**
     * @notice Get shared key
     * @return Shared key
     */
    function _getSharedKey() internal virtual view returns(bytes32);
}