// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/**
 * priceTarget:             when the assets reach this price ratio, position can be closed
 *
 *
 * reward:                  when the bot repays the debt, it gets paid with this amount of supply
 *
 *
 * unwindFactor:            percentage of debt that can be repaid when the position is
 *                          eligible for take profit
 */
struct PNLSettings {
    uint256 priceTarget;
    uint256 fixedReward;
    uint256 percentageReward;
    uint256 unwindFactor;
    bool isTakeProfit;
}

contract PNLStorage {
    bytes32 constant TAKE_PROFIT_LIMIT_STORAGE_POSITION = keccak256('folding.storage.pnl');

    struct PNLStore {
        PNLSettings[] pnlSettings;
    }

    function pnlStore() internal pure returns (PNLStore storage s) {
        bytes32 position = TAKE_PROFIT_LIMIT_STORAGE_POSITION;
        assembly {
            s_slot := position
        }
    }
}
