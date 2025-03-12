// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorCommon} from "src/governor/lib/GovernorCommon.sol";
import {IGovernor} from "src/interfaces/IGovernor.sol";
import {IGovernorTimelockControl} from "src/interfaces/IGovernorTimelockControl.sol";
import {ITimelockController} from "src/interfaces/ITimelockController.sol";
import {AccessControl} from "src/utils/AccessControl.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Origami Governor Timelock Control Facet
 * @author Origami
 * @notice Logic for controlling the timelock queue and execution of proposals.
 * @dev This facet is not intended to be used directly, but rather through the OrigamiGovernorDiamond interface.
 * @custom:security-contact contract-security@joinorigami.com
 */
contract GovernorTimelockControlFacet is IGovernorTimelockControl, AccessControl {
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    /**
     * @notice returns the timelock controller
     * @return the timelock controller
     */
    function timelock() public view returns (ITimelockController) {
        return ITimelockController(GovernorStorage.configStorage().timelock);
    }

    // this function has overloaded behavior in the OZ contracts, acting as a
    // way to count down to execution as well as indicating if it was executed
    // or canceled. We don't need this overloaded functionality since we track
    // execution and cancellation globally in the GovernorStorage contract.
    /**
     * @dev Public accessor to check the eta of a queued proposal
     * @param proposalId the id of the proposal
     * @return the eta of the proposal
     */
    function proposalEta(uint256 proposalId) external view returns (uint256) {
        return GovernorStorage.proposalStorage().timelockQueue[proposalId].timestamp;
    }

    /**
     * @notice queue a set of transactions to be executed after a delay
     * @param targets the targets of the proposal
     * @param values the values of the proposal
     * @param calldatas the calldatas of the proposal
     * @param descriptionHash the hash of the description of the proposal
     * @return proposalId the id of the proposal
     *
     * Regarding slither disable reentrancy: All calls are with trusted contracts.
     */
    // slither-disable-start reentrancy-events
    function queue(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256) {
        uint256 proposalId = GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);

        require(
            GovernorCommon.state(proposalId) == IGovernor.ProposalState.Succeeded, "Governor: proposal not successful"
        );

        uint256 delay = timelock().getMinDelay();
        GovernorStorage.proposalStorage().timelockQueue[proposalId].timestamp = block.timestamp + delay;

        timelock().scheduleBatch(targets, values, calldatas, 0, descriptionHash, delay);

        emit ProposalQueued(proposalId, block.timestamp + delay);

        return proposalId;
    }
    // slither-disable-end reentrancy-events

    /**
     * @notice execute a queued proposal after the delay has passed
     * @param targets the targets of the proposal
     * @param values the values of the proposal
     * @param calldatas the calldatas of the proposal
     * @param descriptionHash the hash of the description of the proposal
     * @return the id of the proposal
     *
     * Regarding slither disable reentrancy: All calls are with trusted contracts.
     */
    // slither-disable-start reentrancy-events
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256) {
        uint256 proposalId = GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);
        require(GovernorCommon.state(proposalId) == IGovernor.ProposalState.Queued, "Governor: proposal not queued");
        timelock().executeBatch{value: msg.value}(targets, values, calldatas, 0, descriptionHash);
        GovernorStorage.proposal(proposalId).executed = true;
        emit ProposalExecuted(proposalId);
        return proposalId;
    }
    // slither-disable-end reentrancy-events

    /**
     * @notice cancel a proposal queued for timelock execution
     * @param targets the targets of the proposal
     * @param values the values of the proposal
     * @param calldatas the calldatas of the proposal
     * @param descriptionHash the hash of the description of the proposal
     * @return the id of the proposal
     */
    function cancel(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external onlyRole(CANCELLER_ROLE) returns (uint256) {
        uint256 proposalId = GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);
        IGovernor.ProposalState state = GovernorCommon.state(proposalId);

        require(
            state != IGovernor.ProposalState.Canceled && state != IGovernor.ProposalState.Expired
                && state != IGovernor.ProposalState.Executed,
            "Governor: proposal not queued"
        );

        GovernorStorage.proposal(proposalId).canceled = true;
        emit ProposalCanceled(proposalId);

        if (GovernorStorage.proposalStorage().timelockQueue[proposalId].timestamp != 0) {
            bytes32 operationHash = timelock().hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
            timelock().cancel(operationHash);
            delete GovernorStorage.proposalStorage().timelockQueue[proposalId];
        }

        return proposalId;
    }

    /**
     * @notice update the timelock address
     * @param newTimelock the new timelock address
     */
    function updateTimelock(address payable newTimelock) external onlyGovernance {
        address oldTimelock = GovernorStorage.configStorage().timelock;
        emit TimelockChange(oldTimelock, newTimelock);
        GovernorStorage.configStorage().timelock = newTimelock;
    }

    modifier onlyGovernance() {
        require(msg.sender == GovernorStorage.configStorage().timelock, "Governor: onlyGovernance");
        _;
    }
}
