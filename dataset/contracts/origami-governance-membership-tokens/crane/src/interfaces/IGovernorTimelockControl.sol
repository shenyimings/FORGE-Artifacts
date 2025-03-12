// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ITimelockController} from "src/interfaces/ITimelockController.sol";

interface IGovernorTimelockControl {
    event TimelockChange(address oldTimelock, address newTimelock);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);

    /**
     * @dev Public accessor to check the eta of a queued proposal
     */
    function proposalEta(uint256 proposalId) external view returns (uint256);

    /**
     * @dev Public accessor to return the address of the timelock
     */
    function timelock() external returns (ITimelockController);

    /**
     * @dev Queue a proposal to be executed after a delay.
     *
     * Emits a {ProposalQueued} event.
     */
    function queue(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    /**
     * @dev Execute a successful proposal. This requires the quorum to be reached, the vote to be successful, and the
     * deadline to be reached.
     *
     * Emits a {ProposalExecuted} event.
     *
     * Note: some module can modify the requirements for execution, for example by adding an additional timelock.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256);

    /**
     * @dev Cancel a proposal. This can only be done if the proposal is still pending or queued, or if the module that
     * implements the {IGovernor} interface has a different implementation for this function.
     *
     * Emits a {ProposalCanceled} event.
     */
    function cancel(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    /**
     * @dev Update the timelock.
     *
     * Emits a {TimelockChange} event.
     */
    function updateTimelock(address payable newTimelock) external;
}
