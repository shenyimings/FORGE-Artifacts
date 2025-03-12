// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

interface IFeeSchedule {
    /**
     * @notice Returns the fees for a given operation type.
     * @param account The account to get the fees for.
     * @param sell Whether the operation is a sell or not.
     */
    function getFeeRatesForOrder(address account, bool sell)
        external
        view
        returns (uint64 perOrderFee, uint24 percentageFeeRate);
}
