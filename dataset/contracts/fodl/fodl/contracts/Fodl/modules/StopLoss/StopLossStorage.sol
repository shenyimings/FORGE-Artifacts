// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

contract StopLossStorage {
    bytes32 constant STOP_LOSS_LIMIT_STORAGE_POSITION = keccak256('folding.storage.stopLoss');

    /**
     * collateralUsageLimit:    when the position collateral usage surpasses this threshold,
     *                          anyone will be able to trigger the stop loss
     *
     * slippageIncentive:       when the bot repays the debt, it will be able to take
     *                          an amount of supply token equivalent to the repaid debt plus
     *                          this incentive specified in percentage.
     *                          It has to be carefully configured with unwind factor
     *
     * unwindFactor:            percentage of debt that can be repaid when the position is
     *                          eligible for stop loss
     */
    struct StopLossStore {
        uint256 collateralUsageLimit; // ranges from 0 to 1e18
        uint256 slippageIncentive; // ranges from 0 to 1e18
        uint256 unwindFactor; // ranges from 0 to 1e18
    }

    function stopLossStore() internal pure returns (StopLossStore storage s) {
        bytes32 position = STOP_LOSS_LIMIT_STORAGE_POSITION;
        assembly {
            s_slot := position
        }
    }
}
