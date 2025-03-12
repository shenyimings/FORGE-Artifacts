// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./CurveStrategyBase.sol";
import "../../../external/interfaces/curve/IStableSwap3Pool.sol";

abstract contract CurveStrategy3CoinsBase is CurveStrategyBase {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */
    
    uint256 internal constant TOTAL_COINS = 3;

    /* ========== STATE VARIABLES ========== */

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

    function _curveDeposit(uint256 amount, uint256 slippage) internal override {
        uint256[TOTAL_COINS] memory amounts;
        amounts[uint128(nCoin)] = amount;

        pool3Coins.add_liquidity(amounts, slippage);
    }

    /* ========== VIRTUAL FUNCTIONS ========== */

    function _getSharedKey() internal virtual view returns(bytes32);
}