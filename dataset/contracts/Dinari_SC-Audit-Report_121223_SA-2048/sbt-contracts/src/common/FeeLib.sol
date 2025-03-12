// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import "prb-math/Common.sol" as PrbMath;
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library FeeLib {
    // 1_000_000 == 100%
    uint24 private constant _ONEHUNDRED_PERCENT = 1_000_000;

    /// @dev Fee is too large
    error FeeTooLarge();
    /// @dev Decimals are too large
    error DecimalsTooLarge();

    function checkPercentageFeeRate(uint24 _percentageFeeRate) internal pure {
        if (_percentageFeeRate >= _ONEHUNDRED_PERCENT) revert FeeTooLarge();
    }

    function percentageFeeForValue(uint256 value, uint24 percentageFeeRate) internal pure returns (uint256) {
        if (percentageFeeRate >= _ONEHUNDRED_PERCENT) revert FeeTooLarge();
        return percentageFeeRate != 0 ? PrbMath.mulDiv(value, percentageFeeRate, _ONEHUNDRED_PERCENT) : 0;
    }

    function flatFeeForOrder(address token, uint64 perOrderFee) internal view returns (uint256 flatFee) {
        uint8 decimals = IERC20Metadata(token).decimals();
        if (decimals > 18) revert DecimalsTooLarge();
        flatFee = perOrderFee;
        if (flatFee != 0 && decimals < 18) {
            flatFee /= 10 ** (18 - decimals);
        }
    }

    function estimateTotalFees(uint256 flatFee, uint24 percentageFeeRate, uint256 orderValue)
        internal
        pure
        returns (uint256 totalFees)
    {
        totalFees = flatFee;
        if (percentageFeeRate != 0) {
            totalFees += PrbMath.mulDiv(orderValue, percentageFeeRate, _ONEHUNDRED_PERCENT);
        }
    }
}
