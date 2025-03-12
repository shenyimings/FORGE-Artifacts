// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IFeeSchedule} from "./IFeeSchedule.sol";

/**
 * @notice This contract handles the fee schedules for BUY/SELL operations
 */
contract FeeSchedule is IFeeSchedule, Ownable2Step {
    struct FeeRates {
        uint64 perOrderFeeBuy;
        uint24 percentageFeeRateBuy;
        uint64 perOrderFeeSell;
        uint24 percentageFeeRateSell;
    }

    event FeesSet(address account, FeeRates feeRates);

    /// @notice Mapping from operation type to its corresponding fee.
    mapping(address account => FeeRates fees) accountFees;

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Returns the fee rates for an account.
     * @param account The account to get the fees for.
     */
    function getFees(address account) external view returns (FeeRates memory) {
        return accountFees[account];
    }

    /// @inheritdoc IFeeSchedule
    function getFeeRatesForOrder(address account, bool sell) external view override returns (uint64, uint24) {
        FeeRates memory feeRates = accountFees[account];
        if (sell) {
            return (feeRates.perOrderFeeSell, feeRates.percentageFeeRateSell);
        } else {
            return (feeRates.perOrderFeeBuy, feeRates.percentageFeeRateBuy);
        }
    }

    /**
     * @notice Sets the fee for a given operation type.
     * @param account The account to set the fees for.
     * @param feeRates The new fee to be set for the operation.
     */
    function setFees(address account, FeeRates memory feeRates) external onlyOwner {
        accountFees[account] = feeRates;
        emit FeesSet(account, feeRates);
    }
}
