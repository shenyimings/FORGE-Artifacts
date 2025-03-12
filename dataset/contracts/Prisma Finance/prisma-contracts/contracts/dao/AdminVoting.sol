// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";
import "../dependencies/DelegatedOps.sol";
import "../dependencies/SystemStart.sol";
import "../interfaces/ITokenLocker.sol";

/**
    @title Prisma DAO Admin Voter
    @notice Primary ownership contract for all Prisma contracts. Allows executing
            arbitrary function calls only after a required percentage of PRISMA
            lockers have signalled in favor of performing the action.
 */
contract AdminVoting is DelegatedOps, SystemStart {
    using Address for address;

    event ProposalCreated(address indexed account, Action[] payload, uint256 week, uint256 requiredWeight);
    event ProposalExecuted(uint256 proposalId);
    event ProposalCancelled(uint256 proposalId);
    event VoteCast(address indexed account, uint256 id, uint256 weight, uint256 proposalCurrentWeight);
    event ProposalCreationMinWeightSet(uint256 weight);
    event ProposalPassingPctSet(uint256 pct);

    struct Proposal {
        uint16 week; // week which vote weights are based upon
        uint32 createdAt; // timestamp when the proposal was created
        uint40 currentWeight; //  amount of weight currently voting in favor
        uint40 requiredWeight; // amount of weight required for the proposal to be executed
        bool processed; // set to true once the proposal is processed
    }

    struct Action {
        address target;
        bytes data;
    }

    uint256 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant MIN_TIME_TO_EXECUTION = 86400;

    ITokenLocker public immutable tokenLocker;
    IPrismaCore public immutable prismaCore;

    Proposal[] proposalData;
    mapping(uint256 => Action[]) proposalPayloads;

    // account -> ID -> amount of weight voted in favor
    mapping(address => mapping(uint256 => uint256)) public accountVoteWeights;

    // absolute amount of weight required to create a new proposal
    uint256 public minCreateProposalWeight;
    // percent of total weight that must vote for a proposal before it can be executed
    uint256 public passingPct;

    constructor(
        address _prismaCore,
        ITokenLocker _tokenLocker,
        uint256 _minCreateProposalWeight,
        uint256 _passingPct
    ) SystemStart(_prismaCore) {
        tokenLocker = _tokenLocker;
        prismaCore = IPrismaCore(_prismaCore);

        minCreateProposalWeight = _minCreateProposalWeight;
        passingPct = _passingPct;
    }

    /**
        @notice The total number of votes created
     */
    function getProposalCount() external view returns (uint256) {
        return proposalData.length;
    }

    /**
        @notice Gets information on a specific proposal
     */
    function getProposalData(
        uint256 id
    )
        external
        view
        returns (
            uint256 week,
            uint256 createdAt,
            uint256 currentWeight,
            uint256 requiredWeight,
            bool executed,
            bool canExecute,
            Action[] memory payload
        )
    {
        Proposal memory proposal = proposalData[id];
        payload = proposalPayloads[id];
        canExecute = (!proposal.processed &&
            proposal.currentWeight >= proposal.requiredWeight &&
            proposal.createdAt + MIN_TIME_TO_EXECUTION < block.timestamp);

        return (
            proposal.week,
            proposal.createdAt,
            proposal.currentWeight,
            proposal.requiredWeight,
            proposal.processed,
            canExecute,
            payload
        );
    }

    /**
        @notice Create a new proposal
        @param payload Tuple of [(target address, calldata), ... ] to be
                       executed if the proposal is passed.
     */
    function createNewProposal(address account, Action[] calldata payload) external callerOrDelegated(account) {
        require(payload.length > 0, "Empty payload");

        // week is set at -1 to the active week so that weights are finalized
        uint256 week = getWeek();
        require(week > 0, "No proposals in first week");
        week -= 1;

        uint256 accountWeight = tokenLocker.getAccountWeightAt(account, week);
        require(accountWeight >= minCreateProposalWeight, "Not enough weight to propose");
        uint256 totalWeight = tokenLocker.getTotalWeightAt(week);
        uint40 requiredWeight = uint40((totalWeight * passingPct) / 100);
        uint256 idx = proposalData.length;
        proposalData.push(
            Proposal({
                week: uint16(week),
                createdAt: uint32(block.timestamp),
                currentWeight: 0,
                requiredWeight: requiredWeight,
                processed: false
            })
        );

        for (uint256 i = 0; i < payload.length; i++) {
            proposalPayloads[idx].push(payload[i]);
        }
        emit ProposalCreated(account, payload, week, requiredWeight);
    }

    /**
        @notice Vote in favor of a proposal
        @dev Each account can vote once per proposal
        @param id Proposal ID
        @param weight Weight to allocate to this action. If set to zero, the full available
                      account weight is used. Integrating protocols may wish to use partial
                      weight to reflect partial support from their own users.
     */
    function voteForProposal(address account, uint256 id, uint256 weight) external callerOrDelegated(account) {
        require(id < proposalData.length, "Invalid ID");
        require(accountVoteWeights[account][id] == 0, "Already voted");

        Proposal memory proposal = proposalData[id];
        require(!proposal.processed, "Proposal already processed");
        require(proposal.createdAt + VOTING_PERIOD > block.timestamp, "Voting period has closed");

        uint256 accountWeight = tokenLocker.getAccountWeightAt(account, proposal.week);
        if (weight == 0) {
            weight = accountWeight;
            require(weight > 0, "No vote weight");
        } else {
            require(weight <= accountWeight, "Weight exceeds account weight");
        }

        accountVoteWeights[account][id] = weight;
        uint40 updatedWeight = uint40(proposal.currentWeight + weight);
        proposalData[id].currentWeight = updatedWeight;
        emit VoteCast(account, id, weight, updatedWeight);
    }

    /**
        @notice Cancels a pending proposal
        @dev Can only be called by the guardian to avoid malicious proposals
             Guardians cannot cancel a proposal for their replacement
        @param id Proposal ID
     */
    function cancelProposal(uint256 id) external {
        require(msg.sender == prismaCore.guardian(), "Only guardian can cancel proposals");
        require(id < proposalData.length, "Invalid ID");
        // We make sure guardians cannot cancel proposals for their replacement
        Action[] storage payload = proposalPayloads[id];
        Action memory firstAction = payload[0];
        bytes memory data = firstAction.data;
        // Extract the call sig from payload data
        bytes4 sig;
        assembly {
            sig := mload(add(data, 0x20))
        }
        require(
            firstAction.target != address(prismaCore) || sig != IPrismaCore.setGuardian.selector,
            "Guardian replacement not cancellable"
        );
        proposalData[id].processed = true;
        emit ProposalCancelled(id);
    }

    /**
        @notice Execute a proposal's payload
        @dev Can only be called if the proposal has received sufficient vote weight,
             and has been active for at least `MIN_TIME_TO_EXECUTION`
        @param id Proposal ID
     */
    function executeProposal(uint256 id) external {
        require(id < proposalData.length, "Invalid ID");
        Proposal memory proposal = proposalData[id];
        require(proposal.currentWeight >= proposal.requiredWeight, "Not passed");
        require(proposal.createdAt + MIN_TIME_TO_EXECUTION < block.timestamp, "MIN_TIME_TO_EXECUTION");
        require(!proposal.processed, "Already processed");
        proposalData[id].processed = true;

        Action[] storage payload = proposalPayloads[id];
        uint256 payloadLength = payload.length;

        for (uint256 i = 0; i < payloadLength; i++) {
            payload[i].target.functionCall(payload[i].data);
        }
        emit ProposalExecuted(id);
    }

    /**
        @notice Set the minimum absolute weight required to create a new proposal
        @dev Only callable via a passing proposal that includes a call
             to this contract and function within it's payload
     */
    function setMinCreateProposalWeight(uint256 weight) external returns (bool) {
        require(msg.sender == address(this), "Only callable via proposal");
        minCreateProposalWeight = weight;
        emit ProposalCreationMinWeightSet(weight);
        return true;
    }

    /**
        @notice Set the required % of the total weight that must vote
                for a proposal prior to being able to execute it
        @dev Only callable via a passing proposal that includes a call
             to this contract and function within it's payload
     */
    function setPassingPct(uint256 pct) external returns (bool) {
        require(msg.sender == address(this), "Only callable via proposal");
        require(pct <= 100, "Invalid value");
        passingPct = pct;
        emit ProposalPassingPctSet(pct);
        return true;
    }

    /**
        @dev Unguarded method to allow accepting ownership transfer of `PrismaCore`
             at the end of the deployment sequence
     */
    function acceptTransferOwnership() external {
        prismaCore.acceptTransferOwnership();
    }
}
