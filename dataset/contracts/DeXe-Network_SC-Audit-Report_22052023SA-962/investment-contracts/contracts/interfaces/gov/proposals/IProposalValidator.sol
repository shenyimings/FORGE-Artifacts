// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../IGovPool.sol";

/**
 * The hook contract that proposals may inherit in order to implement extra validation
 */
interface IProposalValidator {
    /// @notice The hook function
    /// @param actions the proposal "for" actions
    /// @return valid "true" if everything is ok, "false" to revert the proposal creation
    function validate(
        IGovPool.ProposalAction[] calldata actions
    ) external view returns (bool valid);
}
