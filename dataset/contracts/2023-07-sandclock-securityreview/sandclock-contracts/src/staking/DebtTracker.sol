// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

abstract contract DebtTracker {
    using FixedPointMathLib for uint256;

    event DebtAdded(address indexed user, uint256 debt, uint64 timestamp);
    event DebtPaid(address indexed user, uint256 debt);

    error UserHasDebt();

    /// @notice The initial debt for an account
    mapping(address => uint256) public debtOf;

    /// @notice The debt start time for a user
    mapping(address => uint64) public debtStartTimeFor;

    /// @notice The treasury address that recieves any paid debt
    address public treasury;

    /// @notice The amount of current debt left for an account
    function debtFor(address _account) external view returns (uint256) {
        return _debtFor(_account);
    }

    function _updateDebt(address _account) internal {
        // storage loads
        uint64 now_ = uint64(block.timestamp);
        uint256 startTime_ = debtStartTimeFor[_account];

        // if 30 days has passed: eliminate debt
        if (now_ - startTime_ >= 30 days) {
            debtOf[_account] = 0;
        }
    }

    function _debtFor(address _account) internal view returns (uint256) {
        // storage loads
        uint64 now_ = uint64(block.timestamp);
        uint256 startTime = debtStartTimeFor[_account];
        uint256 delta = now_ - startTime;
        uint256 debt = debtOf[_account];

        // if 30 days passed: no debt
        if (delta >= 30 days) return 0;

        // otherwise debt decreases linearly to 0 over 30 days
        return (debt - debt.mulDivDown(delta, 30 days));
    }
}
