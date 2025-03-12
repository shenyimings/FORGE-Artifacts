// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { BattleKey } from "../../types/common.sol";
import { TradeType } from "../../types/enums.sol";

interface ITradeCallback {
    struct TradeCallbackData {
        address payer;
        BattleKey battleKey;
    }

    function tradeCallback(uint256 cAmount, uint256 sAmount, bytes calldata data) external;
}
